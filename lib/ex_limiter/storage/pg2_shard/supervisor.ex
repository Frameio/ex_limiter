defmodule ExLimiter.Storage.PG2Shard.Supervisor do
  @moduledoc """
  Supervisor for the workers and shard router for the PG2Shard
  backend.

  This *must* be manually specified in your supervision tree for this
  storage backend to work.
  """
  use Supervisor
  alias ExLimiter.Storage.PG2Shard.{Worker, Router}
  @telemetry Application.get_env(:ex_limiter, ExLimiter.Storage.PG2Shard)[:telemetry] || Worker

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    shards = Stream.cycle([{Worker, []}]) |> Enum.take(shard_count())
    children = [{Router, []} | shards] |> Enum.reverse()

    :telemetry.attach_many("exlimiter-metrics-handler", Worker.telemetry_events(), &@telemetry.handle_event/4, nil)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def handle_event(_, _, _, _), do: :ok

  defp shard_count() do
    Application.get_env(:ex_limiter, ExLimiter.Storage.PG2Shard)
    |> Keyword.get(:shard_count, 0)
  end
end
