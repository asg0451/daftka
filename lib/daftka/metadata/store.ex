defmodule Daftka.Metadata.Store do
  @moduledoc """
  In-memory metadata store for the MVP.

  Backed by an `Agent` that keeps a simple map of domain metadata.

  Exposed functions use `Daftka.Types` opaque types for safety.
  """

  use Agent
  @name {:via, :swarm, __MODULE__}

  defp server, do: @name

  alias Daftka.Types

  # State structs
  defmodule PartitionMeta do
    @moduledoc false
    @enforce_keys [:owner]
    defstruct owner: nil
  end

  defmodule TopicMeta do
    @moduledoc false
    @enforce_keys [:partitions]
    defstruct partitions: %{}
  end

  defmodule State do
    @moduledoc false
    @enforce_keys [:topics]
    defstruct topics: %{}
  end

  @typedoc "Internal shape of the agent state"
  @opaque state :: %State{
            topics: %{
              required(String.t()) => %TopicMeta{
                partitions: %{non_neg_integer() => %PartitionMeta{owner: pid() | nil}}
              }
            }
          }

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    initial_state = %State{topics: %{}}

    # Register globally with Swarm so there's a single logical store across nodes
    name = {:via, :swarm, __MODULE__}

    case :swarm.whereis_name(__MODULE__) do
      pid when is_pid(pid) -> {:ok, pid}
      _ -> Agent.start_link(fn -> initial_state end, Keyword.merge([name: name], opts))
    end
  end

  ## Topic CRUD

  @doc """
  Create a topic with default of 1 partition.

  Returns `:ok` or `{:error, reason}` where reason is one of:
  - `:invalid_topic`
  - `:topic_exists`
  """
  @spec create_topic(Types.topic()) :: :ok | {:error, :invalid_topic | :topic_exists}
  def create_topic(topic) do
    create_topic(topic, 1)
  end

  @doc """
  Create a topic with a specific number of partitions.

  Returns `:ok` or `{:error, reason}` where reason is one of:
  - `:invalid_topic`
  - `:invalid_partitions`
  - `:topic_exists`
  """
  @spec create_topic(Types.topic(), pos_integer()) ::
          :ok | {:error, :invalid_topic | :invalid_partitions | :topic_exists}
  def create_topic(topic, partitions) when is_integer(partitions) and partitions > 0 do
    with true <- Types.topic?(topic) or {:error, :invalid_topic} do
      topic_key = Types.topic_value(topic)

      Agent.get_and_update(server(), fn %State{topics: topics} = state ->
        if Map.has_key?(topics, topic_key) do
          {{:error, :topic_exists}, state}
        else
          partition_map =
            0..(partitions - 1)
            |> Enum.map(fn idx -> {idx, %PartitionMeta{owner: nil}} end)
            |> Map.new()

          updated_topics = Map.put(topics, topic_key, %TopicMeta{partitions: partition_map})

          {:ok, %State{state | topics: updated_topics}}
        end
      end)
    end
  end

  def create_topic(_topic, _partitions), do: {:error, :invalid_partitions}

  @doc """
  Fetch a topic's metadata.

  Returns `{:ok, meta}` or `{:error, :invalid_topic | :not_found}`. `meta` contains
  `:partitions` (a map of partition index to `%PartitionMeta{owner: pid() | nil}`).
  """
  @type topic_meta :: %TopicMeta{
          partitions: %{non_neg_integer() => %PartitionMeta{owner: pid() | nil}}
        }
  @spec get_topic(Types.topic()) :: {:ok, topic_meta} | {:error, :invalid_topic | :not_found}
  def get_topic(topic) do
    if Types.topic?(topic) do
      topic_key = Types.topic_value(topic)

      Agent.get(server(), fn %State{topics: topics} ->
        case Map.fetch(topics, topic_key) do
          {:ok, meta} -> {:ok, meta}
          :error -> {:error, :not_found}
        end
      end)
    else
      {:error, :invalid_topic}
    end
  end

  @doc """
  List all topics and their metadata.

  Returns a list of `{topic, meta}` where `topic` is a `t:Types.topic/0`.
  """
  @spec list_topics() :: [{Types.topic(), topic_meta}]
  def list_topics do
    Agent.get(server(), fn %State{topics: topics} ->
      Enum.map(topics, fn {name, meta} ->
        {:ok, typed} = Types.new_topic(name)
        {typed, meta}
      end)
    end)
  end

  ## Debug & Inspection

  @doc """
  Return the entire metadata state for debugging and introspection.

  This is not a stable API and may change shape. Intended for internal tooling,
  diagnostics, and tests.
  """
  @spec dump() :: state()
  def dump do
    Agent.get(server(), fn %State{} = state -> state end)
  end

  @doc """
  Delete a topic.

  Returns `:ok` or `{:error, :invalid_topic | :not_found}`.
  """
  @spec delete_topic(Types.topic()) :: :ok | {:error, :invalid_topic | :not_found}
  def delete_topic(topic) do
    if Types.topic?(topic) do
      topic_key = Types.topic_value(topic)

      Agent.get_and_update(server(), fn %State{topics: topics} = state ->
        if Map.has_key?(topics, topic_key) do
          {:ok, %State{state | topics: Map.delete(topics, topic_key)}}
        else
          {{:error, :not_found}, state}
        end
      end)
    else
      {:error, :invalid_topic}
    end
  end

  ## Test support

  @doc false
  @spec clear() :: :ok
  def clear do
    Agent.update(server(), fn _ -> %State{topics: %{}} end)
  end

  ## Partition owners

  @doc """
  Set the owner pid for a topic partition.

  Returns `:ok` or `{:error, reason}` where reason may be
  `:invalid_topic | :invalid_partition | :invalid_pid | :not_found | :partition_out_of_range`.
  """
  @spec set_partition_owner(Types.topic(), Types.partition(), pid()) ::
          :ok | {:error, :invalid_topic | :invalid_partition | :invalid_pid | :not_found}
  def set_partition_owner(topic, partition, owner_pid) do
    with true <- Types.topic?(topic) or {:error, :invalid_topic},
         true <- Types.partition?(partition) or {:error, :invalid_partition},
         true <- is_pid(owner_pid) or {:error, :invalid_pid} do
      topic_key = Types.topic_value(topic)
      partition_index = Types.partition_value(partition)

      Agent.get_and_update(server(), fn %State{topics: topics} = state ->
        with {:ok, %TopicMeta{partitions: partitions} = meta} <- Map.fetch(topics, topic_key),
             {:ok, %PartitionMeta{} = pmeta} <- Map.fetch(partitions, partition_index) do
          updated_pmeta = %PartitionMeta{pmeta | owner: owner_pid}
          updated_partitions = Map.put(partitions, partition_index, updated_pmeta)
          updated_meta = %TopicMeta{meta | partitions: updated_partitions}
          {:ok, %State{state | topics: Map.put(topics, topic_key, updated_meta)}}
        else
          _ -> {{:error, :not_found}, state}
        end
      end)
    end
  end

  @doc """
  Get the owner pid for a topic partition.

  Returns `{:ok, pid}` or `{:error, reason}` where reason may be
  `:invalid_topic | :invalid_partition | :not_found`.
  """
  @spec get_partition_owner(Types.topic(), Types.partition()) ::
          {:ok, pid()} | {:error, :invalid_topic | :invalid_partition | :not_found}
  def get_partition_owner(topic, partition) do
    with true <- Types.topic?(topic) or {:error, :invalid_topic},
         true <- Types.partition?(partition) or {:error, :invalid_partition} do
      topic_key = Types.topic_value(topic)
      partition_index = Types.partition_value(partition)

      Agent.get(server(), fn %State{topics: topics} ->
        with {:ok, %TopicMeta{partitions: partitions}} <- Map.fetch(topics, topic_key),
             {:ok, %PartitionMeta{owner: pid}} <- Map.fetch(partitions, partition_index),
             true <- is_pid(pid) do
          {:ok, pid}
        else
          _ -> {:error, :not_found}
        end
      end)
    end
  end
end
