// Cloudflare Worker that proxies Amazon product lookups so the RapidAPI key
// stays on the server. Only signed-in Firebase users can call it.
import { handleRequest } from './app.ts';
import { createVerifier, googleKeys } from './auth.ts';
import { consumeRateLimit, d1Cache } from './store.ts';

interface Env {
  DB: D1Database;
  FIREBASE_PROJECT_ID: string;
  RAPIDAPI_KEY: string;
}

// Module scope so Google's public keys stay cached between requests.
const keys = googleKeys();

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return handleRequest(request, {
      apiKey: env.RAPIDAPI_KEY,
      fetch: (url, init) => fetch(url, init),
      cache: d1Cache(env.DB),
      verifyToken: createVerifier(env.FIREBASE_PROJECT_ID, keys),
      consumeRateLimit: (uid, limit) => consumeRateLimit(env.DB, uid, limit),
    });
  },
};
