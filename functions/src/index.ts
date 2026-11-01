// Callable Cloud Functions that proxy Amazon product lookups so the
// RapidAPI key stays on the server.
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { CallableRequest, HttpsError, onCall } from 'firebase-functions/v2/https';
import {
  Cache,
  consumeRateLimit,
  Deps,
  parseDetailsParams,
  parseSearchParams,
  productDetails,
  ProxyError,
  RateWindow,
  searchProducts,
} from './amazon.js';

initializeApp();

const rapidApiKey = defineSecret('RAPIDAPI_KEY');

// Server-only cache; client access is denied by firestore.rules.
const firestoreCache: Cache = {
  async get(key) {
    const snap = await getFirestore().collection('api_cache').doc(key).get();
    const data = snap.data();
    if (!data || data.expiresAt.toMillis() < Date.now()) return undefined;
    return data.value;
  },
  async set(key, value, ttlMs) {
    await getFirestore()
      .collection('api_cache')
      .doc(key)
      .set({ value, expiresAt: Timestamp.fromMillis(Date.now() + ttlMs) });
  },
};

const deps = (): Deps => ({ apiKey: rapidApiKey.value(), fetch, cache: firestoreCache });

const options = { secrets: [rapidApiKey], maxInstances: 10, timeoutSeconds: 30 };

function requireAuth(request: CallableRequest): string {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to search products.');
  }
  return request.auth.uid;
}

// Server-only per-user counters; client access is denied by firestore.rules.
async function enforceRateLimit(uid: string) {
  const db = getFirestore();
  const ref = db.collection('rate_limits').doc(uid);
  const allowed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const next = consumeRateLimit(snap.data() as RateWindow | undefined, Date.now());
    if (next) tx.set(ref, next);
    return next !== null;
  });
  if (!allowed) {
    throw new HttpsError('resource-exhausted', 'Too many product requests. Try again later.');
  }
}

async function run<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (e) {
    if (e instanceof ProxyError) throw new HttpsError(e.code, e.message);
    console.error(e);
    throw new HttpsError('internal', 'Unexpected error.');
  }
}

export const amazonSearch = onCall(options, async (request) => {
  await enforceRateLimit(requireAuth(request));
  return run(() => searchProducts(parseSearchParams(request.data), deps()));
});

export const amazonProductDetails = onCall(options, async (request) => {
  await enforceRateLimit(requireAuth(request));
  return run(() => productDetails(parseDetailsParams(request.data), deps()));
});
