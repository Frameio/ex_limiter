defmodule ExLimiter.Storage.PG2Shard.PrunerTest do
  use ExUnit.Case, async: false
  alias ExLimiter.Storage.PG2Shard.Pruner

  @table_name :pruner_test
  describe "#remove" do
    test "it will remove stale bucket entries" do
      table = :ets.new(@table_name, [:set, :public, read_concurrency: true, write_concurrency: true])

      :ets.insert(table, {"bucket", :os.system_time(:millisecond), %ExLimiter.Bucket{}})
      assert Pruner.remove(table, 1) == 1
      assert :ets.lookup(table, "bucket") == []
    end
  end
end
