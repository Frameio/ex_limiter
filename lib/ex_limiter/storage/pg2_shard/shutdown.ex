defmodule ExLimiter.Storage.PG2Shard.Shutdown do
  @moduledoc """
  Traps exits and notifies other nodes to resync on shutdowns.
  """
  use GenServer
  alias ExLimiter.Storage.PG2Shard.{Router, Worker}

  def start_link(_ \\ :ok) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, []}
  end

  def register(pid), do: GenServer.cast(__MODULE__, {:register, pid})

  def handle_cast({:register, pid}, pids) do
    {:noreply, [pid | pids]}
  end

  def terminate(_, pids) do
    Enum.each(pids, &:pg.leave(Worker.group(), &1))
    Node.list() |> Enum.each(&GenServer.cast({Router, &1}, :refresh))
    :timer.sleep(5_000)
  end
end
