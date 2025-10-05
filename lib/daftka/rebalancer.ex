defmodule Daftka.Rebalancer do
  @moduledoc """
  Rebalancer singleton process (skeleton).

  Will monitor metadata and manage partition replica placement.
  """

  use GenServer

  alias Daftka.Metadata.Store
  alias Daftka.PartitionReplica.Supervisor, as: PartitionReplicaSup
  alias Daftka.Partitions.Supervisor, as: PartitionsSup
  alias Daftka.Types
  require Logger

  @default_poll_ms 100

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{poll_ms: @default_poll_ms}
    Process.send_after(self(), :poll, 0)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, %{poll_ms: poll_ms} = state) do
    reconcile()
    Process.send_after(self(), :poll, poll_ms)
    {:noreply, state}
  end

  # Reconcile desired vs actual across all partitions for each topic
  defp reconcile do
    topics = Store.list_topics()
    Enum.each(topics, &reconcile_topic/1)
  end

  defp reconcile_topic({topic, %{partitions: partitions}}) when is_map(partitions) do
    partitions
    |> Map.keys()
    |> Enum.each(&reconcile_partition(topic, &1))
  end

  defp reconcile_topic({topic, _meta}) do
    reconcile_partition(topic, 0)
  end

  defp reconcile_partition(topic, idx) do
    {:ok, p} = Types.new_partition(idx)

    case Store.get_partition_owner(topic, p) do
      {:ok, pid} when is_pid(pid) ->
        if Process.alive?(pid) do
          :ok
        else
          Logger.info(%{
            event: "rebalancer.partition.owner_dead",
            topic: Types.topic_value(topic),
            partition: idx
          })

          start_partition_and_record_owner(topic, idx)
        end

      _ ->
        Logger.info(%{
          event: "rebalancer.partition.no_owner",
          topic: Types.topic_value(topic),
          partition: idx
        })

        start_partition_and_record_owner(topic, idx)
    end
  end

  defp start_partition_and_record_owner(topic, part_index) do
    topic_name = Types.topic_value(topic)
    id = {topic_name, part_index}

    Logger.debug(%{
      event: "rebalancer.ensure_partition_supervisor",
      topic: topic_name,
      partition: part_index
    })

    _ = ensure_partition_supervisor(id)

    server_via = PartitionReplicaSup.server_name(topic_name, part_index)
    server_pid = GenServer.whereis(server_via)

    case server_pid do
      pid when is_pid(pid) ->
        {:ok, p} = Types.new_partition(part_index)
        :ok = Store.set_partition_owner(topic, p, pid)

        Logger.info(%{
          event: "rebalancer.partition.owner_set",
          topic: topic_name,
          partition: part_index,
          owner: inspect(pid)
        })

        :ok

      _ ->
        :ok
    end
  end

  @spec ensure_partition_supervisor({String.t(), non_neg_integer()}) ::
          DynamicSupervisor.on_start_child()
  defp ensure_partition_supervisor({topic, part}) do
    case PartitionsSup.start_partition_supervisor({topic, part}) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
      other -> other
    end
  end
end
