defmodule ExLimiter.PG2Limiter do
  use ExLimiter.Base, storage: ExLimiter.Storage.PG2Shard
end
