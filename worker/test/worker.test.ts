import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { describe, test } from 'node:test';
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from 'jose';
import { handleRequest, type AppDeps } from '../src/app.ts';
import { createVerifier } from '../src/auth.ts';
import { consumeRateLimit, d1Cache } from '../src/store.ts';

// Runs the real SQL on SQLite, the engine behind D1.
function fakeD1(): D1Database {
  const sqlite = new DatabaseSync(':memory:');
  sqlite.exec(readFileSync(new URL('../migrations/0001_init.sql', import.meta.url), 'utf8'));
  const prepare = (sql: string, args: any[] = []): any => ({
    bind: (...next: any[]) => prepare(sql, next),
    first: async () => sqlite.prepare(sql).get(...args) ?? null,
    run: async () => sqlite.prepare(sql).run(...args),
  });
  return { prepare } as unknown as D1Database;
}

const post = (path: string, body: unknown, token: string | null = 'good') =>
  new Request(`https://proxy.test${path}`, {
    method: 'POST',
    headers: token ? { authorization: `Bearer ${token}` } : {},
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });

function appDeps(overrides: Partial<AppDeps> = {}) {
  const calls: string[] = [];
  const deps: AppDeps = {
    apiKey: 'test-key',
    fetch: async (url) => {
      calls.push(url);
      return {
        status: 200,
        json: async () => ({ data: { products: [{ asin: 'B000000001', extra: 'drop' }] } }),
      };
    },
    cache: d1Cache(fakeD1()),
    verifyToken: async (token) => {
      if (token !== 'good') throw new Error('bad token');
      return 'alice';
    },
    consumeRateLimit: async () => true,
    ...overrides,
  };
  return { deps, calls };
}

describe('auth', () => {
  test('rejects missing and invalid tokens without calling RapidAPI', async () => {
    const { deps, calls } = appDeps();
    for (const token of [null, 'bad']) {
      const res = await handleRequest(post('/search', { query: 'cpu' }, token), deps);
      assert.equal(res.status, 401);
      assert.equal(((await res.json()) as any).error.code, 'unauthenticated');
    }
    assert.equal(calls.length, 0);
  });

  test('verifier accepts only tokens for this Firebase project', async () => {
    const { publicKey, privateKey } = await generateKeyPair('RS256');
    const jwk = { ...(await exportJWK(publicKey)), kid: 'k1', alg: 'RS256' };
    const verify = createVerifier('my-project', createLocalJWKSet({ keys: [jwk] }));

    const sign = (project: string, expires = '1h', key = privateKey) =>
      new SignJWT({})
        .setProtectedHeader({ alg: 'RS256', kid: 'k1' })
        .setIssuer(`https://securetoken.google.com/${project}`)
        .setAudience(project)
        .setSubject('alice')
        .setIssuedAt()
        .setExpirationTime(expires)
        .sign(key);

    assert.equal(await verify(await sign('my-project')), 'alice');
    await assert.rejects(verify(await sign('other-project')));
    await assert.rejects(verify(await sign('my-project', '-1h')));
    const stranger = await generateKeyPair('RS256');
    await assert.rejects(verify(await sign('my-project', '1h', stranger.privateKey)));
    await assert.rejects(verify('not-a-token'));
  });
});

describe('routing', () => {
  test('search returns trimmed products', async () => {
    const { deps, calls } = appDeps();
    const res = await handleRequest(post('/search', { query: 'ryzen' }), deps);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { products: [{ asin: 'B000000001' }] });
    assert.match(calls[0], /\/search\?/);
  });

  test('product details route uses the details endpoint', async () => {
    const { deps, calls } = appDeps();
    const res = await handleRequest(post('/product-details', { asin: 'B0BBHD5D8Y' }), deps);
    assert.equal(res.status, 200);
    assert.match(calls[0], /\/product-details\?/);
  });

  test('bad input is a 400', async () => {
    const { deps } = appDeps();
    assert.equal((await handleRequest(post('/search', { query: '' }), deps)).status, 400);
    assert.equal((await handleRequest(post('/search', 'not json'), deps)).status, 400);
  });

  test('unknown routes and wrong methods are rejected', async () => {
    const { deps } = appDeps();
    assert.equal((await handleRequest(post('/other', {}), deps)).status, 404);
    const get = new Request('https://proxy.test/search');
    assert.equal((await handleRequest(get, deps)).status, 405);
  });

  test('CORS preflight needs no token', async () => {
    const { deps } = appDeps();
    const res = await handleRequest(
      new Request('https://proxy.test/search', { method: 'OPTIONS' }),
      deps,
    );
    assert.equal(res.status, 204);
    assert.equal(res.headers.get('access-control-allow-origin'), '*');
  });

  test('over the rate limit is a 429 and skips RapidAPI', async () => {
    const { deps, calls } = appDeps({ consumeRateLimit: async () => false });
    const res = await handleRequest(post('/search', { query: 'cpu' }), deps);
    assert.equal(res.status, 429);
    assert.equal(calls.length, 0);
  });

  test('upstream key problems do not leak details', async () => {
    const { deps } = appDeps({
      fetch: async () => ({ status: 403, json: async () => ({ message: 'key abc is invalid' }) }),
    });
    const res = await handleRequest(post('/search', { query: 'cpu' }), deps);
    assert.equal(res.status, 500);
    assert.doesNotMatch(await res.text(), /abc/);
  });
});

describe('D1 store', () => {
  test('rate limit blocks after the maximum and resets after the window', async () => {
    const db = fakeD1();
    const limit = { maxRequests: 2, windowMs: 1000 };
    assert.equal(await consumeRateLimit(db, 'alice', limit, 0), true);
    assert.equal(await consumeRateLimit(db, 'alice', limit, 10), true);
    assert.equal(await consumeRateLimit(db, 'alice', limit, 20), false);
    assert.equal(await consumeRateLimit(db, 'bob', limit, 20), true);
    assert.equal(await consumeRateLimit(db, 'alice', limit, 1000), true);
  });

  test('cache returns stored values until they expire', async () => {
    let time = 0;
    const cache = d1Cache(fakeD1(), () => time);
    await cache.set('k', { a: 1 }, 100);
    assert.deepEqual(await cache.get('k'), { a: 1 });
    time = 100;
    assert.equal(await cache.get('k'), undefined);
    assert.equal(await cache.get('missing'), undefined);
  });

  test('a second search is served from the cache', async () => {
    const { deps, calls } = appDeps();
    await handleRequest(post('/search', { query: 'ryzen' }), deps);
    await handleRequest(post('/search', { query: 'RYZEN' }), deps);
    assert.equal(calls.length, 1);
  });
});
