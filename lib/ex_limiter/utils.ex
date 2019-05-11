defmodule ExLimiter.Utils do
  def now(), do: :os.system_time(:millisecond)

  def ets_stream(table) do
    Stream.resource(
      fn -> :ets.first(table) end,
      fn :"$end_of_table" -> {:halt, nil}
        previous_key -> {[previous_key], :ets.next(table, previous_key)} end,
      fn _ -> :ok end)
  end

  def parse_integer(val) when is_binary(val), do: Integer.parse(val) |> parse_integer()
  def parse_integer(val) when is_integer(val), do: val
  def parse_integer(:error), do: :error
  def parse_integer({val, _}), do: val
end
