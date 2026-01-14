defmodule ExLimiter.PG2Limiter do
  @moduledoc false
  use ExLimiter.Base, storage: ExLimiter.Storage.PG2Shard
end
