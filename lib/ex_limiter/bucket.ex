defmodule ExLimiter.Bucket do
  @moduledoc false
  @type t :: %__MODULE__{}

  defstruct key: nil,
            value: 0,
            last: nil,
            version: %{}

  def new(key), do: %__MODULE__{key: key, last: System.system_time(:millisecond)}

  def new(contents, key) when is_map(contents) do
    struct(__MODULE__, Map.put(contents, :key, key))
  end
end
