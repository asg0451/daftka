defmodule Daftka.Router do
  @moduledoc """
  Request router (skeleton).

  Will route requests to the current partition leader using metadata.
  """

  use GenServer

  alias Daftka.Metadata.Store
  alias Daftka.PartitionReplica.Server, as: PartitionServer
  alias Daftka.Types

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Daftka.Naming.via_global({:router}))
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  ## Public Router API

  @typedoc """
  Errors that can be returned when resolving a route.
  """
  @type route_error :: {:error, :invalid_topic | :invalid_partition | :not_found}

  @doc """
  Resolve the current owner pid for a topic-partition.

  Returns `{:ok, pid}` or an error tuple.
  """
  @spec route(Types.topic(), Types.partition()) :: {:ok, pid()} | route_error
  def route(topic, partition) do
    Store.get_partition_owner(topic, partition)
  end

  @doc """
  Produce (append) a record via the partition owner.
  Delegates to `Daftka.PartitionReplica.Server.append/4`.
  """
  @spec produce(Types.topic(), Types.partition(), binary(), binary(), Types.headers()) ::
          {:ok, Types.offset()} | {:error, term()}
  def produce(topic, partition, key, value, headers \\ %{}) do
    case route(topic, partition) do
      {:ok, owner} -> PartitionServer.append(owner, key, value, headers)
      error -> error
    end
  end

  @doc """
  Fetch records from a partition via its owner starting from `from_offset`.
  Delegates to `Daftka.PartitionReplica.Server.fetch_from/3`.
  """
  @spec fetch_from(Types.topic(), Types.partition(), Types.offset(), pos_integer()) ::
          {:ok, [Types.message()]} | {:error, term()}
  def fetch_from(topic, partition, from_offset, max_count) do
    case route(topic, partition) do
      {:ok, owner} -> PartitionServer.fetch_from(owner, from_offset, max_count)
      error -> error
    end
  end

  @doc """
  Get the next offset (high-water mark) for a partition via its owner.
  Delegates to `Daftka.PartitionReplica.Server.next_offset/1`.
  """
  @spec next_offset(Types.topic(), Types.partition()) :: {:ok, Types.offset()} | route_error
  def next_offset(topic, partition) do
    case route(topic, partition) do
      {:ok, owner} -> {:ok, PartitionServer.next_offset(owner)}
      error -> error
    end
  end
end
