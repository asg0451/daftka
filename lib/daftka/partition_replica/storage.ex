defmodule Daftka.PartitionReplica.Storage do
  @moduledoc """
  In-memory key/value storage for a single partition replica.

  This MVP implementation is intentionally simple and backed by an `Agent`.
  It will be replaced by a RocksDB-backed implementation in a later milestone.
  """

  use Agent

  @typedoc "The storage process identifier (registered name, PID, or via tuple)."
  @type storage :: GenServer.server()

  @doc """
  Start the storage process.

  Options:
  - `:name` — optional name to register the process under.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} -> Agent.start_link(fn -> %{} end, name: name)
      :error -> Agent.start_link(fn -> %{} end)
    end
  end

  @doc """
  Put a value for a key. Overwrites existing value if present.
  """
  @spec put(storage(), key :: term(), value :: term()) :: :ok
  def put(storage, key, value) do
    Agent.update(storage, fn state -> Map.put(state, key, value) end)
  end

  @doc """
  Get the value for a key.

  Returns `{:ok, value}` when present, or `:error` when absent.
  """
  @spec get(storage(), key :: term()) :: {:ok, term()} | :error
  def get(storage, key) do
    Agent.get(storage, fn state ->
      case state do
        %{^key => value} -> {:ok, value}
        _ -> :error
      end
    end)
  end

  @doc """
  Delete the value for a key. No-op if the key is absent.
  """
  @spec delete(storage(), key :: term()) :: :ok
  def delete(storage, key) do
    Agent.update(storage, fn state -> Map.delete(state, key) end)
  end

  @doc """
  Remove all keys from the storage.
  """
  @spec clear(storage()) :: :ok
  def clear(storage) do
    Agent.update(storage, fn _state -> %{} end)
  end

  @doc """
  Return the number of keys stored.
  """
  @spec size(storage()) :: non_neg_integer()
  def size(storage) do
    Agent.get(storage, &map_size/1)
  end

  @doc """
  Return all keys (in unspecified order).
  """
  @spec keys(storage()) :: [term()]
  def keys(storage) do
    Agent.get(storage, &Map.keys/1)
  end

  @doc """
  Return all values (in unspecified order).
  """
  @spec values(storage()) :: [term()]
  def values(storage) do
    Agent.get(storage, &Map.values/1)
  end
end
