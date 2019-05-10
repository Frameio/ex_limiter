defmodule ExLimiter.Storage.PG2Shard.Router do
  @moduledoc """
  The routing mechanism for pg2 shard instances.  Currently
  it resyncs (by calling `:pg2.get_members/1`) on nodeup/nodedown and
  on a fixed poll interval.

  Ideally we could implement a subscription mechanism in a process grouper like
  swarm that could make this more snappy, but since the workers are statically
  configured anyways, node connect/reconnect is actually a fairly reliable mechanism.
  """
  use GenServer

  @process_group :ex_limiter_shards
  @table_name :ex_limiter_router

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(_) do
    :ok = :net_kernel.monitor_nodes(true, node_type: :all)
    table = :ets.new(@table_name, [:set, :protected, :named_table, {:read_concurrency, true}])
    :ets.insert(table, {:ring, shard_ring()})
    send self(), :resync
    {:ok, table}
  end

  def shard(key) do
    case :ets.lookup(@table_name, :ring) do
      [{:ring, ring}] -> HashRing.key_to_node(ring, key)
      _ -> {:error, :noring}
    end
  end

  def handle_info({:nodeup, _, _}, table) do
    :ets.insert(table, {:ring, shard_ring()})
    {:noreply, table}
  end

  def handle_info({:nodedown, _, _}, table) do
    :ets.insert(table, {:ring, shard_ring()})
    {:noreply, table}
  end

  def handle_info(:resync, table) do
    resync()
    :ets.insert(table, {:ring, shard_ring()})
    {:noreply, table}
  end

  def shards() do
    :pg2.create(@process_group)
    :pg2.get_members(@process_group)
    |> case do
      {:error, _} -> []
      members -> members
    end
  end

  defp shard_ring(), do: HashRing.new() |> HashRing.add_nodes(shards())

  defp resync(), do: Process.send_after(self(), :resync, 10_000)
end
