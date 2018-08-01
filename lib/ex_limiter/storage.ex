defmodule ExLimiter.Storage do
  alias ExLimiter.Bucket
  @type response :: {:ok, Bucket.t} | {:error, any}
  
  @doc """
  Fetch the current state of the given bucket
  """
  @callback fetch(bucket :: Bucket.t) :: Bucket.t

  @doc """
  Set the current state of the given bucket.  Specify hard if you want to
  force a write
  """
  @callback refresh(bucket :: Bucket.t) :: response
  @callback refresh(bucket :: Bucket.t, type :: :hard | :soft) :: response

  @doc """
  Consumes n elements from the bucket (atomically)
  """
  @callback consume(bucket :: Bucket.t, incr :: integer) :: {:ok, Bucket.t}
end