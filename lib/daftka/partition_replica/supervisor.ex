defmodule Daftka.PartitionReplica.Supervisor do
  @moduledoc """
  Per-partition supervisor running Storage and Server (MVP, no raft).

  Strategy is one_for_all to preserve invariants.
  """

  use Supervisor

  @type topic :: String.t()
  @type partition :: non_neg_integer()

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    name = via_name(opts)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  defp via_name(opts) do
    topic = Keyword.fetch!(opts, :topic)
    partition = Keyword.fetch!(opts, :partition)

    {:via, Registry, {Daftka.Registry, {:partition_supervisor, topic, partition}}}
  end

  @impl true
  def init(opts) do
    topic = Keyword.fetch!(opts, :topic)
    partition = Keyword.fetch!(opts, :partition)

    storage_via = storage_name(topic, partition)
    server_via = server_name(topic, partition)

    children = [
      # Raft runtime (placeholder)
      # Daftka.PartitionReplica.Raft,

      # Storage process (placeholder)
      {Daftka.PartitionReplica.Storage, [name: storage_via]},

      # Server (placeholder)
      {Daftka.PartitionReplica.Server, [name: server_via, storage: storage_via]}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  @doc """
  Resolve the via name for a partition's storage process.
  """
  @spec storage_name(topic(), partition()) :: GenServer.name()
  def storage_name(topic, partition) do
    {:via, Registry, {Daftka.Registry, {:partition_storage, topic, partition}}}
  end

  @doc """
  Resolve the via name for a partition's server process.
  """
  @spec server_name(topic(), partition()) :: GenServer.name()
  def server_name(topic, partition) do
    {:via, Registry, {Daftka.Registry, {:partition_server, topic, partition}}}
  end

  @doc """
  Resolve the via name for the partition supervisor itself.
  """
  @spec supervisor_name(topic(), partition()) :: GenServer.name()
  def supervisor_name(topic, partition) do
    {:via, Registry, {Daftka.Registry, {:partition_supervisor, topic, partition}}}
  end
end
