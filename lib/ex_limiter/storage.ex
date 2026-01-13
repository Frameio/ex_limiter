defmodule ExLimiter.Storage do
  @moduledoc false
  alias ExLimiter.Bucket

  defmacro __using__(_) do
    quote do
      @behaviour ExLimiter.Storage

      alias ExLimiter.Bucket

      def leak_and_consume(bucket, update_fn, boundary_fn, incr) do
        with %Bucket{} = bucket <- update(bucket, update_fn),
             %Bucket{} = bucket <- boundary_fn.(bucket),
             do: consume(bucket, incr)
      end

      defoverridable leak_and_consume: 4
    end
  end

  @type response :: {:ok, Bucket.t()} | {:error, any}

  @doc """
  Fetch the current state of the given bucket
  """
  @callback fetch(bucket :: Bucket.t()) :: Bucket.t()

  @doc """
  Set the current state of the given bucket.

  Specify hard if you want to force a write
  """
  @callback refresh(bucket :: Bucket.t()) :: response
  @callback refresh(bucket :: Bucket.t(), type :: :hard | :soft) :: response

  @doc """
  Atomically update the bucket denoted by `key` with `fun`.

  Leverage whatever concurrency controls are available in the given storage mechanism (eg cas for memcached)
  """
  @callback update(key :: binary, fun :: (Bucket.t() -> Bucket.t())) :: Bucket.t()

  @doc """
  Consumes n elements from the bucket (atomically)
  """
  @callback consume(bucket :: Bucket.t(), incr :: integer) :: {:ok, Bucket.t()}

  @callback delete(bucket :: Bucket.t()) :: Bucket.t()
end
