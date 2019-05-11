defmodule ExLimiter.Storage.PG2Shard.Pruner do
  @moduledoc """
  Responsible for creating and pruning a write optimized ets table for
  bucket state
  """
  use GenServer
  import Ex2ms
  alias ExLimiter.Utils

  @table_name :exlimiter_buckets
  @expiry 10 * 60_000
  @eviction_count Application.get_env(:ex_limiter, ExLimiter.Storage.PG2Shard)[:eviction_count] || 1000
  @max_size Application.get_env(:ex_limiter, ExLimiter.Storage.PG2Shard)[:max_size] || 50_000

  def start_link(_args \\ :ok) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    table = :ets.new(@table_name, [:set, :public, read_concurrency: true, write_concurrency: true])
    prune()
    expire()

    {:ok, table}
  end

  def table(), do: GenServer.call(__MODULE__, :fetch)

  def handle_call(:fetch, _from, table), do: {:reply, table, table}

  def handle_info(:expire, table) do
    expire()
    now = Utils.now()
    count = :ets.select_delete(table, fun do {_,_,updated_at} when updated_at < (^now - ^@expiry) -> true end)
    :telemetry.execute([:ex_limiter, :shards, :expired], %{value: count})
    {:noreply, table}
  end

  def handle_info(:prune, table) do
    prune()
    size = :ets.info(table, :size)
    if size >= @max_size do
      count = remove(table, @eviction_count)
      :telemetry.execute([:ex_limiter, :shards, :evictions], %{value: count})
    end
    :telemetry.execute([:ex_limiter, :shards, :map_size], %{value: size})
    {:noreply, table}
  end

  defp remove(table, count) do
    Utils.ets_stream(table)
    |> Stream.take(count)
    |> Stream.each(&:ets.delete(table, &1))
    |> Enum.count()
  end

  defp prune(), do: Process.send_after(self(), :prune, 5_000)

  defp expire(), do: Process.send_after(self(), :expire, 30_000)
end
