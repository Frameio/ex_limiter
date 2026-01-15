defmodule ExLimiter.Plug do
  @moduledoc """
  Plug for enforcing rate limits.

  The usage should be something like

      plug ExLimiter.Plug, scale: 1000, limit: 5

  Additionally, you can pass the following options:

  - `:bucket`, a 1-arity function of a `Plug.Conn.t` which determines
    the bucket for the rate limit. Defaults to the phoenix controller,
    action and remote_ip.

  - `:consumes`, a 1-arity function of a `Plug.Conn.t` which determines
    the amount to consume. Defaults to 1 respectively.

  - `:decorate`, a 2-arity function which can return an updated conn
    based on the outcome of the limiter call. The first argument is the
    `Plug.Conn.t`, and the second can be:

    - `{:ok, Bucket.t}`
    - `{:rate_limited, binary}` Where the second element is the bucket
      name that triggered the rate limit.

  Additionally, you can configure a custom limiter with

      config :ex_limiter, ExLimiter.Plug, limiter: MyLimiter

  and you can also configure the rate limited response with

      config :ex_limiter, ExLimiter.Plug, fallback: MyFallback

  `MyFallback` needs to implement a function `render_error(conn, :rate_limited)`
  """
  import Plug.Conn

  alias ExLimiter.Bucket

  @compile_opts Application.compile_env(:ex_limiter, __MODULE__, [])

  def get_bucket(%{private: %{phoenix_controller: contr, phoenix_action: ac}} = conn), do: "#{contr}.#{ac}.#{ip(conn)}"

  def render_error(conn, :rate_limited) do
    conn
    |> resp(429, "Rate Limit Exceeded")
    |> halt()
  end

  @spec decorate(Plug.Conn.t(), {:ok, Bucket.t()} | {:rate_limited, bucket_name :: binary}) :: Plug.Conn.t()
  def decorate(conn, _), do: conn

  def consume(_conn), do: 1

  def init(opts \\ []) do
    @compile_opts
    |> Keyword.merge(opts)
    |> Keyword.validate!(
      limiter: ExLimiter,
      limit: 10,
      scale: 1000,
      fallback: __MODULE__,
      bucket: &__MODULE__.get_bucket/1,
      consumes: &__MODULE__.consume/1,
      decorate: &__MODULE__.decorate/2
    )
    |> Map.new()
  end

  def call(conn, config) do
    %{
      limiter: limiter,
      bucket: bucket_fun,
      scale: scale,
      limit: limit,
      consumes: consume_fun,
      decorate: decorate_fun,
      fallback: fallback
    } = config

    bucket_name = bucket_fun.(conn)

    case limiter.consume(bucket_name, consume_fun.(conn), scale: scale, limit: limit) do
      {:ok, bucket} = response ->
        remaining = limiter.remaining(bucket, scale: scale, limit: limit)

        conn
        |> put_rate_limit_headers(limit, scale, remaining)
        |> decorate_fun.(response)

      {:error, :rate_limited} ->
        remaining = limiter.remaining(%Bucket{key: bucket_name}, scale: scale, limit: limit)

        conn
        |> put_rate_limit_headers(limit, scale, remaining)
        |> decorate_fun.({:rate_limited, bucket_name})
        |> fallback.render_error(:rate_limited)
    end
  end

  defp put_rate_limit_headers(conn, limit, scale, remaining) do
    conn
    |> put_resp_header("x-ratelimit-limit", Integer.to_string(limit))
    |> put_resp_header("x-ratelimit-window", Integer.to_string(scale))
    |> put_resp_header("x-ratelimit-remaining", Integer.to_string(remaining))
  end

  defp ip(conn), do: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
end
