defmodule ExLimiter.Base do
  @moduledoc """
  Base module for arbitrary rate limiter implementations.  Usage is:

  ```
  defmodule MyLimiter do
    use ExLimiterBase, storage: MyCustomStorage
  end
  ```
  """
  alias ExLimiter.Bucket
  alias ExLimiter.Utils

  defmacro __using__(storage: storage) do
    quote do
      import ExLimiter.Base

      @storage unquote(storage)

      def remaining(%Bucket{value: val}, opts \\ []) do
        limit = Keyword.get(opts, :limit, 10)
        scale = Keyword.get(opts, :scale, 1000)

        round(max(scale - val, 0) / (scale / limit))
      end

      @doc """
      Consumes `amount` from the rate limiter aliased by bucket.

      `opts` params are:
      * `:limit` - the maximum amount for the rate limiter (default 10)
      * `:scale` - the duration under which `:limit` applies in milliseconds
      """
      @spec consume(bucket :: binary, amount :: integer, opts :: keyword) :: {:ok, Bucket.t()} | {:error, :rate_limited}
      def consume(bucket, amount \\ 1, opts \\ []), do: consume(@storage, bucket, amount, opts)

      def delete(bucket), do: @storage.delete(%Bucket{key: bucket})
    end
  end

  @doc """
  Delegate function for rate limiter implementations
  """
  @spec consume(atom, binary, integer, keyword) :: {:ok, Bucket.t()} | {:error, :rate_limited}
  def consume(storage, bucket, amount, opts) do
    limit = Keyword.get(opts, :limit, 10)
    scale = Keyword.get(opts, :scale, 1000)

    mult = scale / limit
    incr = round(amount * mult)

    storage.leak_and_consume(
      bucket,
      fn %Bucket{value: value, last: time} = b ->
        now = Utils.now()
        amount = max(value - (now - time), 0)

        %{b | last: now, value: amount}
      end,
      fn
        %Bucket{value: v} = b when v + incr <= scale -> b
        _ -> {:error, :rate_limited}
      end,
      incr
    )
  end
end
