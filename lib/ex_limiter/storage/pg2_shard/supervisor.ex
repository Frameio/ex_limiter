defmodule ExLimiter.Storage.PG2Shard.Supervisor do
  @moduledoc """
  Supervisor for the workers and shard router for the PG2Shard
  backend.

  This *must* be manually specified in your supervision tree for this
  storage backend to work.
  """
  use Supervisor

  alias ExLimiter.Storage.PG2Shard
  alias ExLimiter.Storage.PG2Shard.Pruner
  alias ExLimiter.Storage.PG2Shard.Router
  alias ExLimiter.Storage.PG2Shard.Shutdown
  alias ExLimiter.Storage.PG2Shard.Worker

  @telemetry Application.compile_env(:ex_limiter, PG2Shard, [])[:telemetry] || Worker

  def start_link(_args \\ :ok) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    shards = [{Worker, []}] |> Stream.cycle() |> Enum.take(shard_count())
    children = Enum.reverse([{Router, []} | shards])
    children = [pg_spec(), {Pruner, []}, {Shutdown, []} | children]

    :telemetry.attach_many("exlimiter-metrics-handler", Worker.telemetry_events(), &@telemetry.handle_event/4, nil)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def handle_event(_, _, _, _), do: :ok

  defp pg_spec do
    %{
      id: :pg,
      start: {:pg, :start_link, []}
    }
  end

  defp shard_count do
    :ex_limiter
    |> Application.get_env(PG2Shard, [])
    |> Keyword.get(:shard_count, 0)
  end
end
