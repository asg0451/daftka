defmodule Daftka.PartitionReplica.Supervisor do
  @moduledoc """
  Per-replica supervisor running Raft, Storage, and Server (skeleton).

  Strategy is one_for_all to preserve invariants.
  """

  use Supervisor

  @type topic :: String.t()
  @type partition :: non_neg_integer()
  @type replica :: non_neg_integer()

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    name = via_name(opts)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  defp via_name(opts) do
    topic = Keyword.fetch!(opts, :topic)
    partition = Keyword.fetch!(opts, :partition)
    replica = Keyword.fetch!(opts, :replica)

    {:via, Registry,
     {Daftka.Registry, {:partition_replica_supervisor, topic, partition, replica}}}
  end

  @impl true
  def init(opts) do
    topic = Keyword.fetch!(opts, :topic)
    partition = Keyword.fetch!(opts, :partition)
    replica = Keyword.fetch!(opts, :replica)

    storage_via = storage_name(topic, partition, replica)
    server_via = server_name(topic, partition, replica)

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
  Resolve the via name for a partition replica's storage process.
  """
  @spec storage_name(topic(), partition(), replica()) :: GenServer.name()
  def storage_name(topic, partition, replica) do
    {:via, Registry, {Daftka.Registry, {:partition_replica_storage, topic, partition, replica}}}
  end

  @doc """
  Resolve the via name for a partition replica's server process.
  """
  @spec server_name(topic(), partition(), replica()) :: GenServer.name()
  def server_name(topic, partition, replica) do
    {:via, Registry, {Daftka.Registry, {:partition_replica_server, topic, partition, replica}}}
  end
end
