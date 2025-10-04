defmodule Daftka.Rebalancer do
  @moduledoc """
  Rebalancer singleton process (MVP).

  Periodically polls the metadata store and ensures that for every topic
  there is a running partition group for partition 0 (single-partition MVP),
  owned by this node. The owner is recorded in the metadata store.
  """

  use GenServer

  alias Daftka.Metadata.Store
  alias Daftka.Partitions.Supervisor, as: PartitionsSupervisor
  alias Daftka.Types

  @typedoc """
  Internal state for the rebalancer process.
  """
  @opaque state :: %{timer_ref: reference() | nil, tick_ms: non_neg_integer()}

  @default_tick_ms 50
  @default_partitions 1

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(keyword()) :: {:ok, state}
  def init(opts) do
    tick_ms = Keyword.get(opts, :tick_ms, @default_tick_ms)
    state = %{timer_ref: nil, tick_ms: tick_ms}
    {:ok, schedule_tick(state, 0)}
  end

  @impl true
  def handle_info(:tick, %{tick_ms: tick_ms} = state) do
    ensure_assignments()
    {:noreply, schedule_tick(state, tick_ms)}
  end

  # ---- Internal helpers ----

  defp schedule_tick(state, timeout_ms) do
    ref = Process.send_after(self(), :tick, timeout_ms)
    %{state | timer_ref: ref}
  end

  defp ensure_assignments do
    topics = Store.list_topics()

    Enum.each(topics, fn {typed_topic, _meta} ->
      topic_name = Types.topic_value(typed_topic)
      ensure_topic_assignments(typed_topic, topic_name)
    end)
  end

  defp ensure_topic_assignments(typed_topic, topic_name) do
    # MVP: 1 partition, 1 replica
    Enum.each(0..(@default_partitions - 1), fn partition_index ->
      {:ok, typed_partition} = Types.new_partition(partition_index)

      desired_supervisor_pid = ensure_partition_replica_started(topic_name, partition_index, 0)

      case Store.get_partition_owner(typed_topic, typed_partition) do
        {:ok, current_owner} ->
          via_pid = partition_replica_supervisor_via_pid(topic_name, partition_index, 0)

          cond do
            is_pid(current_owner) and Process.alive?(current_owner) and current_owner == via_pid ->
              :ok

            true ->
              # Owner missing, dead, or out-of-date: set to the supervisor pid we ensured
              :ok =
                Store.set_partition_owner(typed_topic, typed_partition, desired_supervisor_pid)
          end

        {:error, _} ->
          :ok = Store.set_partition_owner(typed_topic, typed_partition, desired_supervisor_pid)
      end
    end)
  end

  defp ensure_partition_replica_started(topic_name, partition_index, replica_index) do
    via = partition_replica_supervisor_via(topic_name, partition_index, replica_index)

    case GenServer.whereis(via) do
      nil ->
        case PartitionsSupervisor.start_partition_replica_supervisor(
               {topic_name, partition_index, replica_index}
             ) do
          {:ok, pid} ->
            pid

          {:error, {:already_started, pid}} ->
            pid

          {:error, _} ->
            # If start fails for any reason, attempt to resolve via name (may have raced)
            partition_replica_supervisor_via_pid(topic_name, partition_index, replica_index)
        end

      pid when is_pid(pid) ->
        pid
    end
  end

  defp partition_replica_supervisor_via(topic_name, partition_index, replica_index) do
    {:via, Registry,
     {Daftka.Registry,
      {:partition_replica_supervisor, topic_name, partition_index, replica_index}}}
  end

  defp partition_replica_supervisor_via_pid(topic_name, partition_index, replica_index) do
    GenServer.whereis(
      partition_replica_supervisor_via(topic_name, partition_index, replica_index)
    )
  end
end
