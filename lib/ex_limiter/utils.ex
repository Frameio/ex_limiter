defmodule ExLimiter.Utils do
  def now(), do: :os.system_time(:millisecond)

  def parse_integer(val) when is_binary(val), do: Integer.parse(val) |> parse_integer()
  def parse_integer(val) when is_integer(val), do: val
  def parse_integer(:error), do: :error
  def parse_integer({val, _}), do: val
end