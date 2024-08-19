# ex_limiter
Rate Limiter written in elixir with configurable backends

Implements leaky bucket rate limiting ([wiki](https://en.wikipedia.org/wiki/Leaky_bucket)), which is superior to most naive approaches by handling bursts even around time windows.  You can define your own storage backend by implementing the `ExLimiter.Storage` behaviour, and configuring it with

```elixir
config :ex_limiter, :storage, MyStorage
```

If you want to use Memcache as Storage. Add memcachir into your extra_applications in `mix.exs`

```elixir
def application do
  [
    extra_applications: [:memcachir]
  ]
end
```

usage once configured is:

```elixir
case ExLimiter.consume(bucket, 1, scale: 1000, limit: 5) do
  {:ok, bucket} -> #do some work
  {:error, :rate_limited} -> #fail
end
```

Additionally, if you want to have multiple rate limiters with diverse backend implementations you can use the `ExLimiter.Base` macro, like so:

```elixir
defmodule MyLimiter do
  use ExLimiter.Base, storage: MyStorage
end
```
