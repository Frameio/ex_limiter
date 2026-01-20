defmodule ExLimiter.PlugTest do
  use ExLimiter.DataCase

  import Plug.Conn
  import Plug.Test

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
      assert %{last: _, value: _} = bucket_version
    end

    test "it will decorate a connection on error", %{limiter: config, conn: conn} do
      config = %{config | decorate: &decorate/2, limit: 1}
      conn = ExLimiter.Plug.call(conn, config)
      conn = ExLimiter.Plug.call(conn, config)

      assert conn.status == 429

      %{ex_limiter: %{bucket_name: bucket_name}} = conn.assigns

      assert String.ends_with?(bucket_name, "127.0.0.1")
    end

    defp decorate(conn, {:ok, %{key: bucket_name, value: value, last: last}}) do
      assign(conn, :ex_limiter, %{bucket_name: bucket_name, bucket_version: %{last: last, value: value}})
    end

    defp decorate(conn, {:rate_limited, bucket_name}) do
      assign(conn, :ex_limiter, %{bucket_name: bucket_name})
    end
  end

  defp setup_conn(_) do
    random = Base.encode64(:crypto.strong_rand_bytes(8))

    conn =
      :get
      |> conn("/")
      |> merge_private(phoenix_controller: random, phoenix_action: random)

    [conn: conn]
  end

  defp setup_limiter(_) do
    [limiter: ExLimiter.Plug.init(consumes: &consumes/1)]
  end

  defp consumes(%{params: %{"count" => count}}), do: count
  defp consumes(_), do: 1
end
