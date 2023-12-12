defmodule ExLimiter.Base do
  @moduledoc """
  Base module for arbitrary rate limiter implementations.  Usage is:

  ```
  defmodule MyLimiter do
    use ExLimiterBase, storage: MyCustomStorage
  end
  ```
  """
  alias ExLimiter.{Bucket, Utils}

  defmacro __using__(storage: storage) do
    quote do
      import ExLimiter.Base
      @storage unquote(storage)

      @spec remaining(bucket :: binary(), opts :: keyword) :: integer()
      def remaining(bucket, opts \\ [])

      def remaining(bucket, opts) when is_binary(bucket) do
        remaining(@storage, bucket, opts)
      end

      @doc """
      Consumes `amount` from the rate limiter aliased by bucket.

      `opts` params are:
      * `:limit` - the maximum amount for the rate limiter (default 10)
      * `:scale` - the duration under which `:limit` applies in milliseconds
      """
      @spec consume(bucket :: binary, amount :: integer, opts :: keyword) :: {:ok, Bucket.t} | {:error, :rate_limited}
      def consume(bucket, amount \\ 1, opts \\ []) do
        consume(@storage, bucket, amount, opts)
      end

      def delete(bucket), do: @storage.delete(%Bucket{key: bucket})
    end
  end

  @doc """
  Delegate function for rate limiter implementations
  """
  @spec consume(atom, binary, integer, keyword) :: {:ok, Bucket.t} | {:error, :rate_limited}
  def consume(storage, bucket, amount, opts) do
    limit = Keyword.get(opts, :limit, 10)
    scale = Keyword.get(opts, :scale, 1000)

    mult = scale / limit
    incr = round(amount * mult)

    case leak(storage, bucket) do
      %Bucket{value: v} = b when v + incr <= scale -> storage.consume(b, incr)
      _ -> {:error, :rate_limited}
    end
  end

  @spec remaining(atom, binary, keyword) :: integer
  def remaining(storage, bucket, opts) do
    limit = Keyword.get(opts, :limit, 10)
    scale = Keyword.get(opts, :scale, 1000)

    %Bucket{value: val} = leak(storage, bucket)

    mult = Integer.floor_div(scale, limit)

    (scale - val)
    |> Integer.floor_div(mult)
    |> max(0)
  end

  defp leak(storage, bucket) do
    storage.update(bucket, fn %Bucket{value: value, last: time} = b ->
      now    = Utils.now()
      amount = max(value - (now - time), 0)

      %{b | last: now, value: amount}
    end)
  end
end
