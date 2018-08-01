defmodule ExLimiter.PlugTest do
  use ExUnit.Case
  use Plug.Test
  alias ExLimiter.TestUtils 

  describe "#call/2" do
    setup [:setup_limiter, :setup_conn]
    
    test "It will supply rate limiting headers if it passes", %{limiter: config, conn: conn} do
      conn = ExLimiter.Plug.call(conn, config)

      refute Enum.empty?(get_resp_header(conn, "x-ratelimit-limit"))
      refute Enum.empty?(get_resp_header(conn, "x-ratelimit-window"))
      refute Enum.empty?(get_resp_header(conn, "x-ratelimit-remaining"))
    end

    test "It will reject if the rate limit has been exceeded", %{limiter: config, conn: conn} do
      conn =
        %{conn | params: %{"count" => 11}}
         |> ExLimiter.Plug.call(config)

      assert conn.status == 429
    end

    test "it will respect scaling params", %{limiter: config, conn: conn} do
      config = %{config | limit: 1}
      conn = ExLimiter.Plug.call(conn, config)
      
      refute conn.status == 429

      conn = ExLimiter.Plug.call(conn, config)

      assert conn.status == 429
    end
  end

  defp setup_conn(_) do 
    random =  TestUtils.rand_string()
    conn =
      conn(:get, "/")
      |> merge_private(phoenix_controller: random, phoenix_action: random)

    [conn: conn]
  end

  defp setup_limiter(_) do
    [limiter: ExLimiter.Plug.Config.new(consumes: &consumes/1)]
  end

  defp consumes(%{params: %{"count" => count}}), do: count
  defp consumes(_), do: 1
end