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
  alias ExLimiter.Storage.PG2Shard.Pruner

  @process_group :ex_limiter_shards
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
    {:ok, Pruner.table()}
  end

  def handle_call({:update, key, fun}, _from, table) do
    bucket = fetch(table, key) |> fun.()
    {:reply, bucket, upsert(table, key, bucket)}
  end

  def handle_call({:consume, key, amount}, _from, table) do
    %{value: val} = bucket = fetch(table, key)
    bucket = %{bucket | value: val + amount}
    {:reply, bucket, upsert(table, key, bucket)}
  end

  def handle_call({:fetch, key}, _from, table) do
    {:reply, fetch(table, key), table}
  end

  def handle_call({:set, %Bucket{key: k} = bucket}, _from, table) do
    {:reply, bucket, upsert(table, k, bucket)}
  end

  def handle_call({:delete, key}, _from, table) do
    :ets.delete(table, key)
    {:reply, :ok, table}
  end

  def child_spec(_args) do
    %{
      id: make_ref(),
      start: {__MODULE__, :start_link, []}
    }
  end

  def handle_event(_, _, _, _), do: :ok

  def telemetry_events(), do: @telemetry_events

  defp upsert(table, key, bucket) do
    :ets.insert(table, {key, bucket.last, bucket})
    table
  end

  defp fetch(table, key) do
    case :ets.lookup(table, key) do
      [{_, _, bucket}] -> bucket
      _ -> Bucket.new(key)
    end
  end
end
