-- Cached RapidAPI responses (JSON text), expires_at in epoch ms.
CREATE TABLE api_cache (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);

-- Fixed-window request counter per Firebase user.
CREATE TABLE rate_limits (
  uid TEXT PRIMARY KEY,
  start INTEGER NOT NULL,
  count INTEGER NOT NULL
);
