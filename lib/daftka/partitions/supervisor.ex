defmodule Daftka.Partitions.Supervisor do
  @moduledoc """
  Dynamic supervisor managing per-partition supervisors for this node (MVP).
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
  Start a partition supervisor for a given `{topic, partition}` tuple.
  """
  @spec start_partition_supervisor({String.t(), non_neg_integer()}) ::
          DynamicSupervisor.on_start_child()
  def start_partition_supervisor({topic, partition})
      when is_binary(topic) and is_integer(partition) do
    child_spec = %{
      id: {:partition_supervisor, topic, partition},
      start:
        {Daftka.PartitionReplica.Supervisor, :start_link, [[topic: topic, partition: partition]]},
      type: :supervisor,
      restart: :permanent
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
