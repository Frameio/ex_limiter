import Config

config :ex_limiter, ExLimiter.Plug,
  limiter: ExLimiter,
  fallback: ExLimiter.Plug,
  limit: 10,
  scale: 1000

config :ex_limiter, ExLimiter.Storage.PG2Shard, shard_count: 20
config :ex_limiter, :storage, ExLimiter.Storage.Memcache
