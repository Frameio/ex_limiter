defmodule ExLimiter.Storage.PG2ShardTest do
  use ExLimiter.DataCase, async: false

  setup do
    {:ok, bucket_name: bucket_name()}
  end

  describe "#consume" do
    test "it will rate limit", %{bucket_name: bucket_name} do
      {:ok, bucket} = ExLimiter.consume(bucket_name, 1)

      assert bucket.key == bucket_name
      assert bucket.value >= 100

      {:ok, bucket} = ExLimiter.consume(bucket_name, 5)

      assert bucket.value >= 500

      {:error, :rate_limited} = ExLimiter.consume(bucket_name, 6)
    end
  end

  describe "#delete" do
    test "It will wipe a bucket", %{bucket_name: bucket_name} do
      {:ok, bucket} = ExLimiter.consume(bucket_name, 5)

      assert bucket.value >= 500

      ExLimiter.delete(bucket_name)

      {:ok, bucket} = ExLimiter.consume(bucket_name, 1)

      assert bucket.value <= 500
    end
  end

  describe "#remaining" do
    test "It will properly deconvert the remaining capacity in a bucket", %{bucket_name: bucket_name} do
      {:ok, bucket} = ExLimiter.consume(bucket_name, 5)

      assert ExLimiter.remaining(bucket) == 5
    end
  end
end
