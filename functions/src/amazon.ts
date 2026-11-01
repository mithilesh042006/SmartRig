// Amazon product lookups via RapidAPI "Real-Time Amazon Data".
// Kept free of Firebase imports so it can be unit-tested with fakes.
import { createHash } from 'node:crypto';

const HOST = 'real-time-amazon-data.p.rapidapi.com';
const TIMEOUT_MS = 15_000;
const SEARCH_TTL_MS = 6 * 60 * 60 * 1000; // 6 h
const DETAILS_TTL_MS = 24 * 60 * 60 * 1000; // 24 h
const MAX_RESULTS = 10;

export type ErrorCode =
  | 'invalid-argument'
  | 'not-found'
  | 'resource-exhausted'
  | 'deadline-exceeded'
  | 'unavailable'
  | 'internal';

export class ProxyError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
  }
}

export type Fetcher = (
  url: string,
  init: { headers: Record<string, string>; signal: AbortSignal },
) => Promise<{ status: number; json(): Promise<unknown> }>;

export interface Cache {
  get(key: string): Promise<unknown | undefined>;
  set(key: string, value: unknown, ttlMs: number): Promise<void>;
}

export interface Deps {
  apiKey: string;
  fetch: Fetcher;
  cache: Cache;
}

export interface SearchParams {
  query: string;
  country: string;
}

export interface DetailsParams {
  asin: string;
  country: string;
}

type Json = Record<string, unknown>;

// ---- Input validation ----

function asObject(input: unknown): Json {
  if (typeof input !== 'object' || input === null) {
    throw new ProxyError('invalid-argument', 'Request data must be an object.');
  }
  return input as Json;
}

function parseCountry(value: unknown): string {
  if (value === undefined) return 'US';
  if (typeof value !== 'string' || !/^[A-Z]{2}$/.test(value)) {
    throw new ProxyError('invalid-argument', 'country must be a 2-letter code.');
  }
  return value;
}

export function parseSearchParams(input: unknown): SearchParams {
  const data = asObject(input);
  const query = typeof data.query === 'string' ? data.query.trim() : '';
  if (query.length === 0 || query.length > 200) {
    throw new ProxyError('invalid-argument', 'query must be 1–200 characters.');
  }
  return { query, country: parseCountry(data.country) };
}

export function parseDetailsParams(input: unknown): DetailsParams {
  const data = asObject(input);
  const asin = data.asin;
  if (typeof asin !== 'string' || !/^[A-Z0-9]{10}$/.test(asin)) {
    throw new ProxyError('invalid-argument', 'asin must be a 10-character Amazon ID.');
  }
  return { asin, country: parseCountry(data.country) };
}

// ---- Per-user rate limiting ----

/** Fixed window per user; generous enough for a full build session. */
export const RATE_LIMIT = { maxRequests: 120, windowMs: 60 * 60 * 1000 };

export interface RateWindow {
  start: number; // epoch ms
  count: number;
}

/**
 * Counts one request against the caller's window. Returns the window to
 * store, or null when the caller is over the limit.
 */
export function consumeRateLimit(
  current: RateWindow | undefined,
  now: number,
  limit = RATE_LIMIT,
): RateWindow | null {
  if (!current || now - current.start >= limit.windowMs) return { start: now, count: 1 };
  if (current.count >= limit.maxRequests) return null;
  return { start: current.start, count: current.count + 1 };
}

// ---- Upstream calls ----

const cacheKey = (...parts: string[]) =>
  createHash('sha256').update(parts.join('\n')).digest('hex');

async function callRapidApi(path: string, params: Record<string, string>, deps: Deps) {
  const url = `https://${HOST}${path}?${new URLSearchParams(params)}`;
  let response;
  try {
    response = await deps.fetch(url, {
      headers: { 'x-rapidapi-key': deps.apiKey, 'x-rapidapi-host': HOST },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (e) {
    if (e instanceof Error && e.name === 'TimeoutError') {
      throw new ProxyError('deadline-exceeded', 'Product service timed out.');
    }
    throw new ProxyError('unavailable', 'Product service is unreachable.');
  }

  if (response.status === 429) {
    throw new ProxyError('resource-exhausted', 'Product search limit reached. Try again later.');
  }
  if (response.status === 401 || response.status === 403) {
    // Server misconfiguration (bad/expired key); don't leak details to clients.
    throw new ProxyError('internal', 'Product service is misconfigured.');
  }
  if (response.status === 404) {
    throw new ProxyError('not-found', 'Product not found.');
  }
  if (response.status !== 200) {
    throw new ProxyError('unavailable', `Product service error (${response.status}).`);
  }

  const body = (await response.json()) as Json;
  return (body?.data ?? {}) as Json;
}

const pick = (source: Json, keys: string[]): Json =>
  Object.fromEntries(keys.filter((k) => source[k] !== undefined).map((k) => [k, source[k]]));

const SEARCH_FIELDS = [
  'asin',
  'product_title',
  'product_price',
  'product_photo',
  'product_star_rating',
  'product_num_ratings',
  'product_url',
];

const DETAIL_FIELDS = [
  ...SEARCH_FIELDS,
  'product_description',
  'product_photos',
  'product_byline',
  'about_product',
];

/** Returns `{ products: [...] }` with at most 10 trimmed products. */
export async function searchProducts(params: SearchParams, deps: Deps): Promise<Json> {
  const key = cacheKey('search', params.country, params.query.toLowerCase());
  const cached = await deps.cache.get(key);
  if (cached !== undefined) return cached as Json;

  const data = await callRapidApi(
    '/search',
    { query: params.query, country: params.country, page: '1' },
    deps,
  );
  const products = Array.isArray(data.products) ? (data.products as Json[]) : [];
  const result = { products: products.slice(0, MAX_RESULTS).map((p) => pick(p, SEARCH_FIELDS)) };

  await deps.cache.set(key, result, SEARCH_TTL_MS);
  return result;
}

/** Returns the trimmed product-details object. */
export async function productDetails(params: DetailsParams, deps: Deps): Promise<Json> {
  const key = cacheKey('details', params.country, params.asin);
  const cached = await deps.cache.get(key);
  if (cached !== undefined) return cached as Json;

  const data = await callRapidApi(
    '/product-details',
    { asin: params.asin, country: params.country },
    deps,
  );
  const result = pick(data, DETAIL_FIELDS);

  await deps.cache.set(key, result, DETAILS_TTL_MS);
  return result;
}
