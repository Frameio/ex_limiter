# ex_limiter

Rate Limiter written in elixir with configurable backends.

Implements leaky bucket rate limiting ([wiki](https://en.wikipedia.org/wiki/Leaky_bucket)), which is superior to most naive approaches by handling bursts even around time windows. You can define your own storage backend by implementing the `ExLimiter.Storage` behaviour, and configuring it with

```elixir
config :ex_limiter, :storage, MyStorage
```

Usage once configured is:

```elixir
case ExLimiter.consume(bucket, 1, scale: 1000, limit: 5) do
  {:ok, bucket} -> # do some work
  {:error, :rate_limited} -> # fail
end
```

Additionally, if you want to have multiple rate limiters with diverse backend implementations you can use the `ExLimiter.Base` macro, like so:

```elixir
defmodule MyLimiter do
  use ExLimiter.Base, storage: MyStorage
end
```

## ExLimiter.Plug

ExLimiter also ships with a simple plug implementation.  Usage is

```elixir
plug ExLimiter.Plug, scale: 5000, limit: 20
```

You can also configure how the bucket is inferred from the given `conn`, how many tokens to consume and what limiter to use.
