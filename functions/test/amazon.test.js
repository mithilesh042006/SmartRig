const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const {
  parseSearchParams,
  parseDetailsParams,
  searchProducts,
  productDetails,
  ProxyError,
  consumeRateLimit,
} = require('../lib/amazon.js');

function memoryCache() {
  const store = new Map();
  return {
    store,
    async get(key) {
      return store.get(key);
    },
    async set(key, value) {
      store.set(key, value);
    },
  };
}

function fakeFetch(status, body) {
  const calls = [];
  const fn = async (url, init) => {
    calls.push({ url, init });
    return { status, json: async () => body };
  };
  fn.calls = calls;
  return fn;
}

const product = (i) => ({
  asin: `B00000000${i}`,
  product_title: `Product ${i}`,
  product_price: '$10.00',
  secret_internal_field: 'drop me',
});

const rejectsWith = (promise, code) =>
  assert.rejects(promise, (e) => e instanceof ProxyError && e.code === code);

describe('input validation', () => {
  test('search requires a 1–200 character query', () => {
    assert.deepEqual(parseSearchParams({ query: ' Ryzen 5 ' }), { query: 'Ryzen 5', country: 'US' });
    assert.throws(() => parseSearchParams({ query: '' }), ProxyError);
    assert.throws(() => parseSearchParams({ query: 'x'.repeat(201) }), ProxyError);
    assert.throws(() => parseSearchParams(null), ProxyError);
  });

  test('country must be a 2-letter code', () => {
    assert.equal(parseSearchParams({ query: 'a', country: 'GB' }).country, 'GB');
    assert.throws(() => parseSearchParams({ query: 'a', country: 'usa' }), ProxyError);
  });

  test('details requires a valid ASIN', () => {
    assert.equal(parseDetailsParams({ asin: 'B0BBHD5D8Y' }).asin, 'B0BBHD5D8Y');
    assert.throws(() => parseDetailsParams({ asin: '../etc' }), ProxyError);
    assert.throws(() => parseDetailsParams({}), ProxyError);
  });
});

describe('rate limiting', () => {
  const limit = { maxRequests: 2, windowMs: 1000 };

  test('allows up to the limit within a window, then blocks', () => {
    let w = consumeRateLimit(undefined, 0, limit);
    assert.deepEqual(w, { start: 0, count: 1 });
    w = consumeRateLimit(w, 500, limit);
    assert.deepEqual(w, { start: 0, count: 2 });
    assert.equal(consumeRateLimit(w, 999, limit), null);
  });

  test('a new window resets the count', () => {
    const full = { start: 0, count: 2 };
    assert.deepEqual(consumeRateLimit(full, 1000, limit), { start: 1000, count: 1 });
  });
});

describe('searchProducts', () => {
  test('sends the key server-side, trims to 10 products and known fields', async () => {
    const products = Array.from({ length: 15 }, (_, i) => product(i % 10));
    const fetch = fakeFetch(200, { data: { products } });
    const result = await searchProducts(
      { query: 'RTX 4070', country: 'US' },
      { apiKey: 'k', fetch, cache: memoryCache() },
    );

    assert.equal(result.products.length, 10);
    assert.equal(result.products[0].secret_internal_field, undefined);
    assert.equal(result.products[0].product_title, 'Product 0');
    assert.equal(fetch.calls[0].init.headers['x-rapidapi-key'], 'k');
    assert.match(fetch.calls[0].url, /\/search\?query=RTX\+4070&country=US&page=1$/);
  });

  test('second identical search is served from cache', async () => {
    const fetch = fakeFetch(200, { data: { products: [product(1)] } });
    const deps = { apiKey: 'k', fetch, cache: memoryCache() };
    await searchProducts({ query: 'SSD', country: 'US' }, deps);
    await searchProducts({ query: 'ssd', country: 'US' }, deps);
    assert.equal(fetch.calls.length, 1);
  });

  test('maps upstream errors to safe codes', async () => {
    const run = (status) =>
      searchProducts(
        { query: 'x', country: 'US' },
        { apiKey: 'k', fetch: fakeFetch(status, {}), cache: memoryCache() },
      );
    await rejectsWith(run(429), 'resource-exhausted');
    await rejectsWith(run(403), 'internal');
    await rejectsWith(run(500), 'unavailable');
  });

  test('errors are not cached', async () => {
    const cache = memoryCache();
    await rejectsWith(
      searchProducts({ query: 'x', country: 'US' }, { apiKey: 'k', fetch: fakeFetch(500, {}), cache }),
      'unavailable',
    );
    assert.equal(cache.store.size, 0);
  });

  test('network failures and timeouts are reported', async () => {
    const timeout = async () => {
      throw Object.assign(new Error('t'), { name: 'TimeoutError' });
    };
    const offline = async () => {
      throw new TypeError('fetch failed');
    };
    const deps = (fetch) => ({ apiKey: 'k', fetch, cache: memoryCache() });
    await rejectsWith(searchProducts({ query: 'x', country: 'US' }, deps(timeout)), 'deadline-exceeded');
    await rejectsWith(searchProducts({ query: 'x', country: 'US' }, deps(offline)), 'unavailable');
  });
});

describe('productDetails', () => {
  test('returns trimmed details and caches them', async () => {
    const fetch = fakeFetch(200, {
      data: { ...product(1), about_product: ['Fast'], product_byline: 'Brand' },
    });
    const deps = { apiKey: 'k', fetch, cache: memoryCache() };
    const result = await productDetails({ asin: 'B000000001', country: 'US' }, deps);
    await productDetails({ asin: 'B000000001', country: 'US' }, deps);

    assert.deepEqual(result.about_product, ['Fast']);
    assert.equal(result.secret_internal_field, undefined);
    assert.equal(fetch.calls.length, 1);
  });

  test('404 becomes not-found', async () => {
    await rejectsWith(
      productDetails(
        { asin: 'B000000001', country: 'US' },
        { apiKey: 'k', fetch: fakeFetch(404, {}), cache: memoryCache() },
      ),
      'not-found',
    );
  });
});
