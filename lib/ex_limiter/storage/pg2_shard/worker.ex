defmodule ExLimiter.Storage.PG2Shard.Worker do
  @moduledoc """
  Simple Genserver for implementing the `ExLimiter.Storage` behavior for a set
  of buckets.

  Buckets are pruned after 10 minutes of inactivity, and buckets will be evicted
  if a maximum threshold is reached.  To tune these values, use:

  ```
  config :ex_limiter, ExLimiter.Storage.PG2Shard,
    max_size: 50_000,
    eviction_count: 1000
  ```

  It will also publish these metrics via telemetry:

  ```
  [:ex_limiter, :shards, :map_size],
  [:ex_limiter, :shards, :evictions],
  [:ex_limiter, :shards, :expirations]
  ```

  You can auto-configure a telemetry handler via:

  ```
  config :ex_limiter, ExLimiter.Storage.PG2Shard,
    telemetry: MyTelemetryHandler
  ```
  """
  use GenServer
  alias ExLimiter.Bucket
  alias ExLimiter.Utils

  @process_group :ex_limiter_shards
  @expiry 10 * 60_000
  @eviction_count Application.get_env(:ex_limiter, ExLimiter.Storage.PG2Shard)[:eviction_count] || 1000
  @max_size Application.get_env(:ex_limiter, ExLimiter.Storage.PG2Shard)[:max_size] || 50_000
  @telemetry_events [
    [:ex_limiter, :shards, :map_size],
    [:ex_limiter, :shards, :evictions],
    [:ex_limiter, :shards, :expirations]
  ]

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    :pg2.create(@process_group)
    :pg2.join(@process_group, self())
    prune()

    {:ok, %{}}
  end

  def handle_call({:update, key, fun}, _from, buckets) do
    bucket = fetch(buckets, key) |> fun.()
    {:reply, bucket, upsert(buckets, key, bucket)}
  end

  def handle_call({:consume, key, amount}, _from, buckets) do
    %{value: val} = bucket = fetch(buckets, key)
    bucket = %{bucket | value: val + amount}
    {:reply, bucket, upsert(buckets, key, bucket)}
  end

  def handle_call({:fetch, key}, _from, buckets) do
    {:reply, fetch(buckets, key), buckets}
  end

  def handle_call({:set, %Bucket{key: k} = bucket}, _from, buckets) do
    {:reply, bucket, upsert(buckets, k, bucket)}
  end

  def handle_call({:delete, key}, _from, buckets) do
    {:reply, :ok, Map.delete(buckets, key)}
  end

  def handle_info(:prune, buckets) do
    now = Utils.now()
    to_drop = for {k, %{last: last}} <- buckets, now - @expiry > last, do: k
    buckets = Map.drop(buckets, to_drop)

    :telemetry.execute([:ex_limiter, :shards, :map_size], %{value: map_size(buckets)})
    :telemetry.execute([:ex_limiter, :shards, :expirations], %{value: length(to_drop)})
    {:noreply, buckets}
  end

  def child_spec(_args) do
    %{
      id: make_ref(),
      start: {__MODULE__, :start_link, []}
    }
  end

  def handle_event(_, _, _, _), do: :ok

  def telemetry_events(), do: @telemetry_events

  defp upsert(buckets, key, bucket) when map_size(buckets) >= @max_size do
    to_delete =
      Enum.sort_by(buckets, fn {_, %{last: last}} -> last end)
      |> Enum.take(@eviction_count)
      |> Enum.map(&elem(&1, 0))

    :telemetry.execute([:ex_limiter, :shards, :evictions], %{value: length(to_delete)})
    buckets
    |> Map.drop(to_delete)
    |> Map.put(key, bucket)
  end
  defp upsert(buckets, key, bucket), do: Map.put(buckets, key, bucket)

  defp fetch(buckets, key) do
    case buckets do
      %{^key => bucket} -> bucket
      _ -> Bucket.new(key)
    end
  end

  defp prune(), do: Process.send_after(self(), :prune, 30_000)
end
