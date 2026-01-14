defmodule ExLimiter.Storage.PG2Shard.PrunerTest do
  use ExLimiter.DataCase, async: false

  alias ExLimiter.Storage.PG2Shard.Pruner

  describe "#remove" do
    test "it will remove stale bucket entries" do
      table = :ets.new(:pruner_test, [:set, :public, read_concurrency: true, write_concurrency: true])

      :ets.insert(table, {"bucket", System.system_time(:millisecond), %ExLimiter.Bucket{}})
      assert Pruner.remove(table, 1) == 1
      assert :ets.lookup(table, "bucket") == []
    end
  end

  describe "#expire" do
    def expiration_handler([:ex_limiter, :shards, :expirations], %{value: count}, _, %{test_pid: test_pid}) do
      send(test_pid, {:expired_records, count})
    end

    test "it will remove expired bucket entries" do
      table_name = :expired_test
      table = :ets.new(table_name, [:set, :public, read_concurrency: true, write_concurrency: true])

      # Listen for the expirations events so we can assert on it
      test_pid = self()

      :telemetry.attach("expiration-test", [:ex_limiter, :shards, :expirations], &__MODULE__.expiration_handler/4, %{
        test_pid: test_pid
      })

      on_exit(fn -> :telemetry.detach("expiration-test") end)

      time = System.system_time(:millisecond) - to_timeout(second: 100)

      :ets.insert(table, {"bucket", time, %ExLimiter.Bucket{}})

      assert Pruner.handle_info(:expire, table) == {:noreply, table}

      assert_receive {:expired_records, 1}, to_timeout(second: 5)
      assert :ets.lookup(table, "bucket") == []
    end
  end
end
