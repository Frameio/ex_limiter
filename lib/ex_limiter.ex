defmodule ExLimiter do
  @moduledoc """
  Configurable, leaky bucket rate limiting.

  You can define your own storage backend by
  implementing the `ExLimiter.Storage` behaviour, and configuring it with

    config :ex_limiter, :storage, MyStorage


  usage once configured is:

      case ExLimiter.consume(bucket, 1, scale: 1000, limit: 5) do
        {:ok, bucket} -> #do some work
        {:error, :rate_limited} -> #fail
      end

  Additionally, if you want to have multiple rate limiters with diverse backend implementations,
  you can use the `ExLimiter.Base` macro, like so:

      defmodule MyLimiter do
        use ExLimiter.Base, storage: MyStorage
      end
  """
  use ExLimiter.Base, storage: Application.compile_env(:ex_limiter, :storage, ExLimiter.Storage.Memcache)
end
