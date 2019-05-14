defmodule ExLimiter.Storage.PG2Shard do
  @moduledoc """
  Implements the leaky bucket using a fleet of GenServers discoverable via a
  pg2 group.

  To configure the pool size, do:

  ```
  config :ex_limit, ExLimiter.Storage.PG2Shard,
    shard_count: 20
  ```

  You must also include the shard supervisor in your app supervision tree, with
  something like:

  ```
  ...
  supervise(ExLimiter.Storage.PG2Shard.Supervisor, [])
  ```
  """
  use ExLimiter.Storage
  alias ExLimiter.Storage.PG2Shard.Router

  def fetch(%Bucket{key: key}),
    do: with_worker(key, &call(&1, {:fetch, key}))

  def refresh(%Bucket{key: key} = bucket, _type \\ :soft),
    do: {:ok, with_worker(key, &call(&1, {:set, bucket}))}

  def delete(%Bucket{key: key} = bucket) do
    with_worker(key, &call(&1, {:delete, key}))
    bucket
  end

  def update(key, update_fun), do: with_worker(key, &call(&1, {:update, key, update_fun}))

  def consume(%Bucket{key: key}, incr),
    do: {:ok, with_worker(key, &call(&1, {:consume, key, incr}))}

  def leak_and_consume(key, update_fn, boundary_fn, incr) do
    with_worker(key, fn pid ->
      call(pid, {:leak_and_consume, key, update_fn, boundary_fn, incr})
    end, {:ok, Bucket.new(key)})
  end

  defp call(pid, operation), do: GenServer.call(pid, operation)

  defp with_worker(key, fun, fallback \\ nil) do
    try do
      case Router.shard(key) do
        pid when is_pid(pid) -> fun.(pid)
        _ -> fallback || Bucket.new(key)
      end
    rescue
      _error -> fallback || Bucket.new(key)
    catch
      :exit, _ -> fallback || Bucket.new(key)
    end
  end
end
