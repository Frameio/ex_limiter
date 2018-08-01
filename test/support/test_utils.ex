defmodule ExLimiter.TestUtils do
  def rand_string() do
    :crypto.strong_rand_bytes(8) 
    |> Base.encode64()
  end
end