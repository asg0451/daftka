defmodule Daftka.Metadata.Store do
  @moduledoc """
  In-memory metadata store for the MVP.

  Backed by an `Agent` that keeps a simple map of domain metadata.

  Exposed functions use `Daftka.Types` opaque types for safety.
  """

  use Agent

  alias Daftka.Types

  # State structs
  defmodule TopicMeta do
    @moduledoc false
    @enforce_keys [:owners]
    defstruct owners: %{}
  end

  defmodule State do
    @moduledoc false
    @enforce_keys [:topics]
    defstruct topics: %{}
  end

  @typedoc "Internal shape of the agent state"
  @opaque state :: %State{
            topics: %{required(String.t()) => %TopicMeta{owners: %{non_neg_integer() => pid()}}}
          }

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    initial_state = %State{topics: %{}}
    Agent.start_link(fn -> initial_state end, Keyword.merge([name: __MODULE__], opts))
  end

  ## Topic CRUD

  @doc """
  Create a topic.

  Returns `:ok` or `{:error, reason}` where reason is one of:
  - `:invalid_topic`
  - `:topic_exists`
  """
  @spec create_topic(Types.topic()) :: :ok | {:error, :invalid_topic | :topic_exists}
  def create_topic(topic) do
    case Types.topic?(topic) do
      true ->
        topic_key = Types.topic_value(topic)

        Agent.get_and_update(__MODULE__, fn %State{topics: topics} = state ->
          if Map.has_key?(topics, topic_key) do
            {{:error, :topic_exists}, state}
          else
            updated_topics = Map.put(topics, topic_key, %TopicMeta{owners: %{}})
            {:ok, %State{state | topics: updated_topics}}
          end
        end)

      false ->
        {:error, :invalid_topic}
    end
  end

  @doc """
  Fetch a topic's metadata.

  Returns `{:ok, meta}` or `{:error, :invalid_topic | :not_found}`. `meta` contains
  `:owners` (a map of partition index to owner pid).
  """
  @type topic_meta :: %TopicMeta{owners: %{non_neg_integer() => pid()}}
  @spec get_topic(Types.topic()) :: {:ok, topic_meta} | {:error, :invalid_topic | :not_found}
  def get_topic(topic) do
    if Types.topic?(topic) do
      topic_key = Types.topic_value(topic)

      Agent.get(__MODULE__, fn %State{topics: topics} ->
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
    Agent.get(__MODULE__, fn %State{topics: topics} ->
      Enum.map(topics, fn {name, meta} ->
        {:ok, typed} = Types.new_topic(name)
        {typed, meta}
      end)
    end)
  end

  @doc """
  Delete a topic.

  Returns `:ok` or `{:error, :invalid_topic | :not_found}`.
  """
  @spec delete_topic(Types.topic()) :: :ok | {:error, :invalid_topic | :not_found}
  def delete_topic(topic) do
    if Types.topic?(topic) do
      topic_key = Types.topic_value(topic)

      Agent.get_and_update(__MODULE__, fn %State{topics: topics} = state ->
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
    Agent.update(__MODULE__, fn _ -> %State{topics: %{}} end)
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
    cond do
      not Types.topic?(topic) ->
        {:error, :invalid_topic}

      not Types.partition?(partition) ->
        {:error, :invalid_partition}

      not is_pid(owner_pid) ->
        {:error, :invalid_pid}

      true ->
        topic_key = Types.topic_value(topic)
        partition_index = Types.partition_value(partition)

        Agent.get_and_update(__MODULE__, fn %State{topics: topics} = state ->
          case Map.fetch(topics, topic_key) do
            :error ->
              {{:error, :not_found}, state}

            {:ok, %TopicMeta{owners: owners} = meta} ->
              updated_meta = %TopicMeta{
                meta
                | owners: Map.put(owners, partition_index, owner_pid)
              }

              {:ok, %State{state | topics: Map.put(topics, topic_key, updated_meta)}}
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
    cond do
      not Types.topic?(topic) ->
        {:error, :invalid_topic}

      not Types.partition?(partition) ->
        {:error, :invalid_partition}

      true ->
        topic_key = Types.topic_value(topic)
        partition_index = Types.partition_value(partition)

        Agent.get(__MODULE__, fn %State{topics: topics} ->
          with {:ok, %TopicMeta{owners: owners}} <- Map.fetch(topics, topic_key),
               {:ok, pid} <- Map.fetch(owners, partition_index) do
            {:ok, pid}
          else
            :error -> {:error, :not_found}
            _ -> {:error, :not_found}
          end
        end)
    end
  end
end
