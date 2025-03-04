defmodule ExLimiter.Utils do
  @moduledoc false
  def now, do: :os.system_time(:millisecond)

  def batched_ets(table, match_spec \\ {:"$1", :_, :_}, batch_size \\ 1000, total \\ 100_000, fnc) do
    table
    |> :ets.match(match_spec, batch_size)
    |> process_batch(0, total, fnc)
  end

  defp process_batch(_, count, total, _) when count >= total, do: count

  defp process_batch({elem, cnt}, count, total, fnc) do
    fnc.(elem)

    cnt
    |> :ets.match()
    |> process_batch(length(elem) + count, total, fnc)
  end

  defp process_batch(:"$end_of_table", count, _, _), do: count

  def ets_stream(table) do
    Stream.resource(
      fn -> :ets.first(table) end,
      fn
        :"$end_of_table" -> {:halt, nil}
        previous_key -> {[previous_key], :ets.next(table, previous_key)}
      end,
      fn _ -> :ok end
    )
  end

  def parse_integer(val) when is_binary(val), do: val |> Integer.parse() |> parse_integer()
  def parse_integer(val) when is_integer(val), do: val
  def parse_integer(:error), do: :error
  def parse_integer({val, _}), do: val
end
