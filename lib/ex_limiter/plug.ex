defmodule ExLimiter.Plug do
  @moduledoc """
  Plug for enforcing rate limits.  The usage should be something like

  ```
  plug ExLimiter.Plug, scale: 1000, limit: 5
  ```

  Additionally, you can pass in `:bucket` or `:consumes` as options, each of which
  are 1-arity functions of a `Plug.Conn.t` which determine the bucket for the rate limit
  and the amount to consume.  These default to the phoenix controller, action, and remote_ip
  and 1 respectively.

  Additionally, you can configure a custom limiter with

  ```
  config :ex_limiter, ExLimiter.Plug, limiter: MyLimiter
  ```
  
  and you can also configure the rate limited response with

  ```
  config :ex_limiter, ExLimiter.Plug, fallback: MyFallback
  ```

  `MyFallback` needs to implement a function `render_error(conn, :rate_limited)`
  """
  import Plug.Conn

  @limiter Application.get_env(:ex_limiter, __MODULE__)[:limiter]
  @fallback Application.get_env(:ex_limiter, __MODULE__)[:fallback]
  

  defmodule Config do
    @limit Application.get_env(:ex_limiter, ExLimiter.Plug)[:limit]
    @scale Application.get_env(:ex_limiter, ExLimiter.Plug)[:scale]

    defstruct [
      scale: @scale,
      limit: @limit,
      bucket: &ExLimiter.Plug.get_bucket/1,
      consumes: nil
    ]

    def new(opts) do
      contents =
        Enum.into(opts, %{})
        |> Map.put_new(:consumes, fn _ -> 1 end)

      struct(__MODULE__, contents)
    end
  end

  def get_bucket(%{private: %{phoenix_controller: contr, phoenix_action: ac}} = conn) do
    "#{contr}.#{ac}.#{ip(conn)}"
  end

  def render_error(conn, :rate_limited) do
    conn
    |> resp(429, "Rate Limit Exceeded")
    |> halt()
  end

  def init(opts), do: Config.new(opts)

  def call(conn, %Config{bucket: bucket_fun, scale: scale, limit: limit, consumes: consume_fun}) do
    bucket_fun.(conn)
    |> @limiter.consume(consume_fun.(conn), scale: scale, limit: limit)
    |> case do
      {:ok, bucket} ->
        remaining = @limiter.remaining(bucket, scale: scale, limit: limit)

        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-window", to_string(scale))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
      {:error, :rate_limited} -> @fallback.render_error(conn, :rate_limited)
    end
  end

  defp ip(conn), do: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
end