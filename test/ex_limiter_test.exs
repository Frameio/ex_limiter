defmodule ExLimiterTest do
  use ExUnit.Case
  alias ExLimiter.TestUtils
  doctest ExLimiter

  describe "#consume" do
    test "it will rate limit" do
      bucket_name = bucket()
      {:ok, bucket} = ExLimiter.consume(bucket_name, 1)
      
      assert bucket.key == bucket_name
      assert bucket.value >= 100

      {:ok, bucket} = ExLimiter.consume(bucket_name, 5)

      assert bucket.value >= 500

      {:error, :rate_limited} = ExLimiter.consume(bucket_name, 6)
    end
  end

  defp bucket() do
    "test_bucket_#{TestUtils.rand_string()}"
  end
end
