defmodule ExLimiter.Bucket do
  alias ExLimiter.Utils

  @type t :: %__MODULE__{}

  defstruct [
    key: nil,
    value: 0,
    last: nil,
    version: %{}
  ]

  def new(key), do: %__MODULE__{key: key, last: Utils.now()}

  def new(contents, key) when is_map(contents) do
    struct(__MODULE__, Map.put(contents, :key, key))
  end
end