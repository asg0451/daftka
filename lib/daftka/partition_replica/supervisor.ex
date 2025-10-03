defmodule Daftka.PartitionReplica.Supervisor do
  @moduledoc """
  Per-replica supervisor running Raft, Storage, and Server (skeleton).

  Strategy is one_for_all to preserve invariants.
  """

  use Supervisor

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
    _topic = Keyword.fetch!(opts, :topic)
    _partition = Keyword.fetch!(opts, :partition)
    _replica = Keyword.fetch!(opts, :replica)

    children = [
      # Raft runtime (placeholder)
      # Daftka.PartitionReplica.Raft,

      # Storage process (placeholder)
      Daftka.PartitionReplica.Storage,

      # Server (placeholder)
      Daftka.PartitionReplica.Server
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
