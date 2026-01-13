defmodule ExLimiter.Storage.PG2Shard.Pruner do
  @moduledoc """
  Responsible for creating and pruning a write optimized ets table for
  bucket state
  """
  use GenServer

  alias ExLimiter.Storage.PG2Shard
  alias ExLimiter.Utils

  @table_name :exlimiter_buckets
  @compile_opts Application.compile_env(:ex_limiter, PG2Shard, [])
  @expiry @compile_opts[:expiry] || @eviction_count(@compile_opts[:eviction_count] || 1000)
  @max_size @compile_opts[:max_size] || 50_000
  @prune_interval @compile_opts[:prune_interval] || 5_000
  @eviction_interval @compile_opts[:eviction_interval] || 30_000

  def start_link(_args \\ :ok) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    table = :ets.new(@table_name, [:set, :public, read_concurrency: true, write_concurrency: true])
    prune()
    expire()

    {:ok, table}
  end

  def table, do: GenServer.call(__MODULE__, :fetch)

  def handle_call(:fetch, _from, table), do: {:reply, table, table}

  def handle_info(:expire, table) do
    expire()
    now = Utils.now()

    count =
      :ets.select_delete(
        table,
        [
          {{:_, :"$1", :_}, [{:<, :"$1", {:-, {:const, now}, {:const, @expiry}}}], [true]}
        ]
      )

    :telemetry.execute([:ex_limiter, :shards, :expirations], %{value: count})
    {:noreply, table}
  end

  def handle_info(:prune, table) do
    prune()
    size = :ets.info(table, :size)

    if size >= @max_size do
      count = remove(table, @eviction_count)
      :telemetry.execute([:ex_limiter, :shards, :evictions], %{value: count})
    end

    :telemetry.execute([:ex_limiter, :shards, :size], %{value: size})
    {:noreply, table, :hibernate}
  end

  def remove(table, count) do
    Utils.batched_ets(table, {:"$1", :_, :_}, 1000, count, fn keys ->
      for [key] <- keys,
          do: :ets.delete(table, key)
    end)
  end

  defp prune, do: Process.send_after(self(), :prune, @prune_interval)

  defp expire, do: Process.send_after(self(), :expire, @eviction_interval)
end
