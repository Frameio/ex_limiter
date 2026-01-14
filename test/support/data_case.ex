defmodule ExLimiter.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import ExLimiter.DataCase
    end
  end

  def bucket_name, do: Base.encode64(:crypto.strong_rand_bytes(8))
end
