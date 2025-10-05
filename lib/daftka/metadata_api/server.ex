defmodule Daftka.MetadataAPI.Server do
  @moduledoc """
  Metadata API server for control-plane operations (MVP).

  Exposes a typed, in-VM API for managing topics. For the MVP this is a thin
  facade over the in-memory `Daftka.Metadata.Store` and does not maintain any
  internal state beyond being a supervised process.
  """

  use GenServer

  alias Daftka.Metadata.Store
  alias Daftka.Types

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  ## Public API (facade over Metadata.Store)

  @doc """
  Create a topic by name.

  Returns `:ok` or `{:error, :invalid_topic | :topic_exists}`.
  """
  @spec create_topic(String.t()) :: :ok | {:error, :invalid_topic | :topic_exists}
  def create_topic(name) when is_binary(name) do
    with {:ok, topic} <- Types.new_topic(name) do
      Store.create_topic(topic)
    end
  end

  def create_topic(_), do: {:error, :invalid_topic}

  @doc """
  Create a topic by name with a specific number of partitions.

  Returns `:ok` or `{:error, :invalid_topic | :invalid_partitions | :topic_exists}`.
  """
  @spec create_topic(String.t(), pos_integer()) ::
          :ok | {:error, :invalid_topic | :invalid_partitions | :topic_exists}
  def create_topic(name, partitions) when is_binary(name) and is_integer(partitions) do
    with {:ok, topic} <- Types.new_topic(name) do
      Store.create_topic(topic, partitions)
    end
  end

  def create_topic(_, _), do: {:error, :invalid_topic}

  @typedoc """
  Topic metadata value returned by `get_topic/1`.
  Uses the metadata shape from `Daftka.Metadata.Store`.
  """
  @type topic_meta :: Store.topic_meta()

  @doc """
  Fetch metadata for a topic by name.

  Returns `{:ok, meta}` or `{:error, :invalid_topic | :not_found}`.
  """
  @spec get_topic(String.t()) :: {:ok, topic_meta} | {:error, :invalid_topic | :not_found}
  def get_topic(name) when is_binary(name) do
    with {:ok, topic} <- Types.new_topic(name) do
      Store.get_topic(topic)
    end
  end

  def get_topic(_), do: {:error, :invalid_topic}

  @doc """
  Delete a topic by name.

  Returns `:ok` or `{:error, :invalid_topic | :not_found}`.
  """
  @spec delete_topic(String.t()) :: :ok | {:error, :invalid_topic | :not_found}
  def delete_topic(name) when is_binary(name) do
    with {:ok, topic} <- Types.new_topic(name) do
      Store.delete_topic(topic)
    end
  end

  def delete_topic(_), do: {:error, :invalid_topic}

  @doc """
  List all topics.

  Returns a list of `{Types.topic(), topic_meta}` tuples.
  """
  @spec list_topics() :: [{Types.topic(), topic_meta}]
  def list_topics do
    Store.list_topics()
  end

  @doc """
  DEBUG: Return the entire cluster metadata state from the store.

  Intended for diagnostics and tests only; API is not stable.
  """
  @spec debug_dump() :: Store.state()
  def debug_dump do
    Store.dump()
  end

  @doc """
  Wait for a partition replica server for `{topic, partition}` to be online.

  Returns `:ok` when the server is registered and reachable, or
  `{:error, :timeout}` if not available within `timeout_ms`.

  Validates inputs via `Types`.
  """
  @spec wait_for_online(String.t(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, :invalid_topic | :invalid_partition | :timeout}
  def wait_for_online(topic_name, partition_index, timeout_ms \\ 5_000)

  def wait_for_online(topic_name, partition_index, timeout_ms)
      when is_binary(topic_name) and is_integer(partition_index) and is_integer(timeout_ms) and
             timeout_ms >= 0 do
    with {:ok, topic} <- Types.new_topic(topic_name),
         {:ok, partition} <- Types.new_partition(partition_index) do
      do_wait_for_online(topic, partition, timeout_ms)
    end
  end

  def wait_for_online(_topic_name, _partition_index, _timeout_ms), do: {:error, :invalid_topic}

  @spec do_wait_for_online(Types.topic(), Types.partition(), non_neg_integer()) ::
          :ok | {:error, :timeout}
  defp do_wait_for_online(topic, partition, timeout_ms) do
    topic_str = Types.topic_value(topic)
    part_idx = Types.partition_value(partition)
    via = Daftka.PartitionReplica.Supervisor.server_name(topic_str, part_idx)

    deadline = System.monotonic_time(:millisecond) + timeout_ms
    poll_interval = 50

    do_wait_for_online_loop(via, deadline, poll_interval)
  end

  defp do_wait_for_online_loop(via, deadline, poll_interval) do
    case GenServer.whereis(via) do
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          :ok
        else
          wait_or_timeout(via, deadline, poll_interval)
        end

      _ ->
        wait_or_timeout(via, deadline, poll_interval)
    end
  end

  defp wait_or_timeout(via, deadline, poll_interval) do
    if System.monotonic_time(:millisecond) >= deadline do
      {:error, :timeout}
    else
      Process.sleep(poll_interval)
      do_wait_for_online_loop(via, deadline, poll_interval)
    end
  end
end
