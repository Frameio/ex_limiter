defmodule ExLimiter.Storage.Memcache do
  @moduledoc """
  Token bucket backend written for memcache. Stores the last timestamp
  and amount in separate keys, and utilizes memcache increments for consumption 
  """
  @behaviour ExLimiter.Storage
  alias ExLimiter.{Bucket, Utils}

  def fetch(%Bucket{key: key}) do
    key_map = keys(key)

    Map.keys(key_map) 
    |> Memcachir.mget(cas: true)
    |> case do
      {:ok, result} -> from_memcached(result, key, key_map)
      _ -> Bucket.new(key)
    end
  end

  def refresh(%Bucket{key: key} = bucket, _type \\ :soft) do
    keys(key)
    |> Enum.map(&mset_command(&1, bucket))
    |> Memcachir.mset_cas()
    |> case do
      {:ok, _} -> {:ok, bucket}
      {:error, error} -> {:error, error}
    end
  end

  def consume(%Bucket{key: key} = bucket, inc) do
    case Memcachir.incr("amount_#{key}", inc) do
      {:ok, result} -> {:ok, %{bucket | value: result}}
      _ -> {:ok, Bucket.new(key)}
    end
  end

  defp keys(key), do: %{"amount_#{key}" => :value, "last_#{key}" => :last}

  defp from_memcached(map, key, key_map) when is_map(map) do
    key_map
    |> Enum.reduce(%{version: %{}}, &reduce_memcached(&1, &2, map))
    |> Enum.into(%{})
    |> Bucket.new(key)
  end

  defp mset_command({key, bucket_key}, %Bucket{version: versions} = b) do 
    value = Map.get(b, bucket_key) |> to_string()
    {key, value, Map.get(versions, bucket_key, 0)}
  end

  defp reduce_memcached({key, bucket_key}, acc, map), do: add_result(acc, bucket_key, map[key])

  defp add_result(%{version: versions} = acc, bucket_key, {val, cas}) do
    acc
    |> Map.put(bucket_key, Utils.parse_integer(val))
    |> Map.put(:version, Map.put(versions, bucket_key, cas))
  end
  defp add_result(acc, bucket_key, _), do: add_result(acc, bucket_key, default(bucket_key))

  defp default(:value), do: {0, 0}
  defp default(:last), do: {Utils.now(), 0}
end