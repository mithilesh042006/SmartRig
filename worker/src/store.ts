// D1-backed response cache and per-user rate limit.
import type { Cache } from '../../functions/src/amazon.ts';

export function d1Cache(db: D1Database, now = Date.now): Cache {
  return {
    async get(key) {
      const row = await db
        .prepare('SELECT value FROM api_cache WHERE key = ?1 AND expires_at > ?2')
        .bind(key, now())
        .first<{ value: string }>();
      return row ? JSON.parse(row.value) : undefined;
    },
    async set(key, value, ttlMs) {
      await db
        .prepare('INSERT OR REPLACE INTO api_cache (key, value, expires_at) VALUES (?1, ?2, ?3)')
        .bind(key, JSON.stringify(value), now() + ttlMs)
        .run();
    },
  };
}

/**
 * Counts one request in a single atomic statement, so parallel requests can't
 * slip past the limit. Resolves to false when the caller is over the limit.
 */
export async function consumeRateLimit(
  db: D1Database,
  uid: string,
  limit: { maxRequests: number; windowMs: number },
  now = Date.now(),
): Promise<boolean> {
  const row = await db
    .prepare(
      `INSERT INTO rate_limits (uid, start, count) VALUES (?1, ?2, 1)
       ON CONFLICT (uid) DO UPDATE SET
         start = CASE WHEN ?2 - start >= ?3 THEN ?2 ELSE start END,
         count = CASE WHEN ?2 - start >= ?3 THEN 1 ELSE count + 1 END
       RETURNING count`,
    )
    .bind(uid, now, limit.windowMs)
    .first<{ count: number }>();
  return row !== null && row.count <= limit.maxRequests;
}
