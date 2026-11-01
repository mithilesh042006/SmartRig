// HTTP routing for the Amazon proxy: auth, rate limit, then the shared lookups.
import {
  parseDetailsParams,
  parseSearchParams,
  productDetails,
  ProxyError,
  RATE_LIMIT,
  searchProducts,
  type Deps,
} from '../../functions/src/amazon.ts';
import type { TokenVerifier } from './auth.ts';

export interface AppDeps extends Deps {
  verifyToken: TokenVerifier;
  /** Resolves to false when the user is over their request limit. */
  consumeRateLimit(uid: string, limit: typeof RATE_LIMIT): Promise<boolean>;
}

const STATUS: Record<string, number> = {
  'invalid-argument': 400,
  unauthenticated: 401,
  'not-found': 404,
  'resource-exhausted': 429,
  internal: 500,
  unavailable: 503,
  'deadline-exceeded': 504,
};

// Requests are authorised by bearer token, not cookies, so any origin is safe.
const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...CORS },
  });

const failure = (code: string, message: string) =>
  json(STATUS[code] ?? 500, { error: { code, message } });

class HttpError extends Error {
  constructor(
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

async function requireUser(request: Request, deps: AppDeps): Promise<string> {
  const token = request.headers.get('authorization')?.match(/^Bearer (.+)$/)?.[1];
  try {
    if (token) return await deps.verifyToken(token);
  } catch {
    // Falls through to the same response as a missing token.
  }
  throw new HttpError('unauthenticated', 'Sign in to search products.');
}

async function readBody(request: Request): Promise<unknown> {
  try {
    return await request.json();
  } catch {
    throw new ProxyError('invalid-argument', 'Request body must be JSON.');
  }
}

export async function handleRequest(request: Request, deps: AppDeps): Promise<Response> {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });

  const { pathname } = new URL(request.url);
  if (pathname !== '/search' && pathname !== '/product-details') {
    return failure('not-found', 'Unknown route.');
  }
  if (request.method !== 'POST') {
    return json(405, { error: { code: 'method-not-allowed', message: 'Use POST.' } });
  }

  try {
    const uid = await requireUser(request, deps);
    if (!(await deps.consumeRateLimit(uid, RATE_LIMIT))) {
      throw new HttpError('resource-exhausted', 'Too many product requests. Try again later.');
    }
    const body = await readBody(request);
    const result =
      pathname === '/search'
        ? await searchProducts(parseSearchParams(body), deps)
        : await productDetails(parseDetailsParams(body), deps);
    return json(200, result);
  } catch (e) {
    if (e instanceof ProxyError || e instanceof HttpError) return failure(e.code, e.message);
    console.error(e);
    return failure('internal', 'Unexpected error.');
  }
}
