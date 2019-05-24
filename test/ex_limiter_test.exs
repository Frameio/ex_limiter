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

    test "it will rate limit for custom scale/limits" do
      bucket_name = bucket()
      args = [scale: 60_000, limit: 50]
      {:ok, bucket} = ExLimiter.consume(bucket_name, 1, args)

      assert bucket.key == bucket_name
      assert bucket.value >= 100

      for _ <- 0..10, do: {:ok, _} = ExLimiter.consume(bucket_name, 1, args)

      assert bucket.value >= 500

      {:error, :rate_limited} = ExLimiter.consume(bucket_name, 40, args)
    end
  end

  describe "#delete" do
    test "It will wipe a bucket" do
      bucket_name = bucket()

      {:ok, bucket} = ExLimiter.consume(bucket_name, 5)

      assert bucket.value >= 500

      ExLimiter.delete(bucket_name)

      {:ok, bucket} = ExLimiter.consume(bucket_name, 1)

      assert bucket.value <= 500
    end
  end

  describe "#remaining" do
    test "It will properly deconvert the remaining capacity in a bucket" do
      bucket_name = bucket()

      {:ok, bucket} = ExLimiter.consume(bucket_name, 5)

      assert ExLimiter.remaining(bucket) == 5
    end
  end

  defp bucket() do
    "test_bucket_#{TestUtils.rand_string()}"
  end
end
