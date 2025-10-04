defmodule Daftka.PartitionReplica.Server do
  @moduledoc """
  Partition Group MVP: thin GenServer wrapper over the storage actor.

  Exposes append/fetch and high-watermark operations, delegating to
  `Daftka.PartitionReplica.Storage`.
  """

  use GenServer

  alias Daftka.PartitionReplica.Storage
  alias Daftka.Types

  @opaque state :: %{storage: GenServer.server()}

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    storage = Keyword.get(opts, :storage, Storage)
    GenServer.start_link(__MODULE__, %{storage: storage}, name: name)
  end

  @doc """
  Append a message to this partition replica via the underlying storage.
  Returns `{:ok, offset}` or an error tuple from storage.
  """
  @spec append(GenServer.server(), binary(), binary(), Types.headers()) ::
          {:ok, Types.offset()} | {:error, term()}
  def append(server \\ __MODULE__, key, value, headers \\ %{}) do
    GenServer.call(server, {:append, key, value, headers})
  end

  @doc """
  Fetch up to `max_count` messages starting from `from_offset` (inclusive).
  Delegates to storage.
  """
  @spec fetch_from(GenServer.server(), Types.offset(), pos_integer()) ::
          {:ok, [Types.message()]} | {:error, term()}
  def fetch_from(server \\ __MODULE__, from_offset, max_count) do
    GenServer.call(server, {:fetch_from, from_offset, max_count})
  end

  @doc """
  Return the current high-water mark (next offset) for this partition.
  """
  @spec next_offset(GenServer.server()) :: Types.offset()
  def next_offset(server \\ __MODULE__) do
    GenServer.call(server, :next_offset)
  end

  # Server callbacks

  @impl true
  def init(%{storage: storage}) do
    {:ok, %{storage: storage}}
  end

  @impl true
  def handle_call(:next_offset, _from, %{storage: storage} = state) do
    {:reply, Storage.next_offset(storage), state}
  end

  def handle_call({:append, key, value, headers}, _from, %{storage: storage} = state) do
    {:reply, Storage.append(storage, key, value, headers), state}
  end

  def handle_call({:fetch_from, from_offset, max_count}, _from, %{storage: storage} = state) do
    {:reply, Storage.fetch_from(storage, from_offset, max_count), state}
  end
end
