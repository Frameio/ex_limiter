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

      def remaining(%Bucket{value: val}, opts \\ []) do
        limit = Keyword.get(opts, :limit, 10)
        scale = Keyword.get(opts, :scale, 1000)

        round((scale - val) / limit)
      end

      @doc """
      Consumes `amount` from the rate limiter aliased by bucket. 
      
      `opts` params are:
      * `:limit` - the maximum amount for the rate limiter (default 10)
      * `:scale` - the duration under which `:limit` applies in milliseconds
      """
      @spec consume(bucket :: binary, amount :: integer, opts :: keyword) :: {:ok, Bucket.t} | {:error, :rate_limited}
      def consume(bucket, amount \\ 1, opts \\ []),
        do: consume(@storage, bucket, amount, opts)
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

  defp leak(storage, bucket) do
    %Bucket{value: value, last: time} = bucket = storage.fetch(%Bucket{key: bucket})
    now    = Utils.now()
    amount = max(value - (now - time), 0)
    
    # the latency of whatever storage should be sufficiently low that we can
    # simply refetch and not miss too many drips (while catching a previous decrement)
    storage.refresh(%{bucket | last: now, value: amount})
    |> case do
      {:ok, bucket} -> bucket
      _ -> storage.fetch(bucket)
    end
  end
end