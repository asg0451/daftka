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

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    topic = Keyword.fetch!(opts, :topic)
    partition = Keyword.fetch!(opts, :partition)

    %{
      id: "partition_supervisor:" <> topic <> ":" <> Integer.to_string(partition),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent
    }
  end

  # kept for external lookups if needed
  defp via_name(opts) do
    topic = Keyword.fetch!(opts, :topic)
    partition = Keyword.fetch!(opts, :partition)
    {:via, Registry, {Daftka.Registry, {:partition_supervisor, topic, partition}}}
  end

  def init(opts) do
    topic = Keyword.fetch!(opts, :topic)
    partition = Keyword.fetch!(opts, :partition)

    storage_via = storage_name(topic, partition)
    server_via = server_name(topic, partition)

    children = [
      # Raft runtime (placeholder)
      # Daftka.PartitionReplica.Raft,

      # Storage process (placeholder)
      %{
        id: "partition_storage:" <> topic <> ":" <> Integer.to_string(partition),
        start:
          {Daftka.PartitionReplica.Storage, :start_link,
           [[topic: topic, partition: partition, name: storage_via]]},
        type: :worker,
        restart: :permanent
      },

      # Server (placeholder)
      %{
        id: "partition_server:" <> topic <> ":" <> Integer.to_string(partition),
        start:
          {Daftka.PartitionReplica.Server, :start_link,
           [[topic: topic, partition: partition, name: server_via, storage: storage_via]]},
        type: :worker,
        restart: :permanent
      }
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

  # No local atom names to avoid unbounded atom creation
end
