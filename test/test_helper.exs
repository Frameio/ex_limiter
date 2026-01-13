Application.put_env(:ex_limiter, ExLimiter.Storage.PG2Shard, shard_count: 20)
ExUnit.start()
{:ok, _pid} = ExLimiter.Storage.PG2Shard.Supervisor.start_link()
