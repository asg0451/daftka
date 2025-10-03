defmodule Daftka.Partitions.Supervisor do
  @moduledoc """
  Dynamic supervisor managing PartitionReplica supervisors for this node (skeleton).
  """

  use DynamicSupervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a partition replica supervisor for a given identifier tuple.
  """
  @spec start_partition_replica_supervisor({String.t(), non_neg_integer(), non_neg_integer()}) ::
          DynamicSupervisor.on_start_child()
  def start_partition_replica_supervisor({topic, partition, replica} = id)
      when is_binary(topic) and is_integer(partition) and is_integer(replica) do
    child_spec = %{
      id: {:partition_replica, id},
      start:
        {Daftka.PartitionReplica.Supervisor, :start_link,
         [[topic: topic, partition: partition, replica: replica]]},
      type: :supervisor,
      restart: :permanent
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
