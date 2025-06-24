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
      conn = ExLimiter.Plug.call(%{conn | params: %{"count" => 11}}, config)

      assert conn.status == 429

      for header <- ~w(x-ratelimit-limit x-ratelimit-window x-ratelimit-remaining) do
        value = conn |> get_resp_header(header) |> List.first()

        assert {_integer, ""} = Integer.parse(value)
      end
    end

    test "it will respect scaling params", %{limiter: config, conn: conn} do
      config = %{config | limit: 1}
      conn = ExLimiter.Plug.call(conn, config)

      refute conn.status == 429

      conn = ExLimiter.Plug.call(conn, config)

      assert conn.status == 429
    end

    test "it will decorate a connection on ok", %{limiter: config, conn: conn} do
      config = %{config | decorate: &decorate/2}
      conn = ExLimiter.Plug.call(conn, config)

      refute conn.status == 429

      %{ex_limiter: %{bucket_name: bucket_name, bucket_version: bucket_version}} = conn.assigns

      assert String.ends_with?(bucket_name, "127.0.0.1")
      assert bucket_version == %{last: 0, value: 0}
    end

    test "it will decorate a connection on error", %{limiter: config, conn: conn} do
      config = %{config | decorate: &decorate/2, limit: 1}
      conn = ExLimiter.Plug.call(conn, config)
      conn = ExLimiter.Plug.call(conn, config)

      assert conn.status == 429

      %{ex_limiter: %{bucket_name: bucket_name}} = conn.assigns

      assert String.ends_with?(bucket_name, "127.0.0.1")
    end
  end

  defp decorate(conn, {:ok, %{key: bucket_name, version: bucket_version}}) do
    assign(conn, :ex_limiter, %{bucket_name: bucket_name, bucket_version: bucket_version})
  end
  defp decorate(conn, {:rate_limited, bucket_name}) do
    assign(conn, :ex_limiter, %{bucket_name: bucket_name})
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
