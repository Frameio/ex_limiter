defmodule ExLimiter.Storage.PG2ShardTest do
  use ExUnit.Case, async: false
  alias ExLimiter.PG2Limiter
  alias ExLimiter.TestUtils

  describe "#consume" do
    test "it will rate limit" do
      bucket_name = bucket()
      {:ok, bucket} = PG2Limiter.consume(bucket_name, 1)

      assert bucket.key == bucket_name
      assert bucket.value >= 100

      {:ok, bucket} = PG2Limiter.consume(bucket_name, 5)

      assert bucket.value >= 500

      {:error, :rate_limited} = PG2Limiter.consume(bucket_name, 6)
    end
  end

  describe "#delete" do
    test "It will wipe a bucket" do
      bucket_name = bucket()

      {:ok, bucket} = PG2Limiter.consume(bucket_name, 5)

      assert bucket.value >= 500

      PG2Limiter.delete(bucket_name)

      {:ok, bucket} = PG2Limiter.consume(bucket_name, 1)

      assert bucket.value <= 500
    end
  end

  describe "#remaining" do
    test "It will properly deconvert the remaining capacity in a bucket" do
      bucket_name = bucket()

      {:ok, bucket} = PG2Limiter.consume(bucket_name, 5)

      assert PG2Limiter.remaining(bucket) == 5
    end
  end

  defp bucket() do
    "test_bucket_#{TestUtils.rand_string()}"
  end
end
