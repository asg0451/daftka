defmodule Daftka.Metadata.Store do
  @moduledoc """
  In-memory metadata store for the MVP.

  Backed by an `Agent` that keeps a simple map of domain metadata.

  Exposed functions use `Daftka.Types` opaque types for safety.
  """

  use Agent

  alias Daftka.Types

  @typedoc "Internal shape of the agent state"
  @opaque state :: %{
            required(:topics) => %{
              required(String.t()) => %{
                partition_count: pos_integer(),
                owners: %{optional(non_neg_integer()) => pid()}
              }
            }
          }

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    initial_state = %{topics: %{}}
    Agent.start_link(fn -> initial_state end, Keyword.merge([name: __MODULE__], opts))
  end

  ## Topic CRUD

  @doc """
  Create a topic with the given number of partitions.

  Returns `:ok` or `{:error, reason}` where reason is one of:
  - `:invalid_topic`
  - `:invalid_partitions`
  - `:topic_exists`
  """
  @spec create_topic(Types.topic(), pos_integer()) ::
          :ok | {:error, :invalid_topic | :invalid_partitions | :topic_exists}
  def create_topic(topic, partition_count) do
    with true <- Types.topic?(topic) || {:error, :invalid_topic},
         true <-
           (is_integer(partition_count) and partition_count > 0) ||
             {:error, :invalid_partitions} do
      topic_key = Types.topic_value(topic)

      Agent.get_and_update(__MODULE__, fn %{topics: topics} = state ->
        if Map.has_key?(topics, topic_key) do
          {{:error, :topic_exists}, state}
        else
          updated_topics =
            Map.put(topics, topic_key, %{partition_count: partition_count, owners: %{}})

          {:ok, %{state | topics: updated_topics}}
        end
      end)
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :invalid_topic}
    end
  end

  @doc """
  Fetch a topic's metadata.

  Returns `{:ok, meta}` or `{:error, :invalid_topic | :not_found}`. `meta` contains
  `:partition_count` and `:owners` (a map of partition index to owner pid).
  """
  @spec get_topic(Types.topic()) ::
          {:ok,
           %{partition_count: pos_integer(), owners: %{optional(non_neg_integer()) => pid()}}}
          | {:error, :invalid_topic | :not_found}
  def get_topic(topic) do
    if Types.topic?(topic) do
      topic_key = Types.topic_value(topic)

      Agent.get(__MODULE__, fn %{topics: topics} ->
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
  @spec list_topics() ::
          [
            {Types.topic(),
             %{partition_count: pos_integer(), owners: %{optional(non_neg_integer()) => pid()}}}
          ]
  def list_topics do
    Agent.get(__MODULE__, fn %{topics: topics} ->
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

      Agent.get_and_update(__MODULE__, fn %{topics: topics} = state ->
        if Map.has_key?(topics, topic_key) do
          {:ok, %{state | topics: Map.delete(topics, topic_key)}}
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
    Agent.update(__MODULE__, fn _ -> %{topics: %{}} end)
  end

  ## Partition owners

  @doc """
  Set the owner pid for a topic partition.

  Returns `:ok` or `{:error, reason}` where reason may be
  `:invalid_topic | :invalid_partition | :invalid_pid | :not_found | :partition_out_of_range`.
  """
  @spec set_partition_owner(Types.topic(), Types.partition(), pid()) ::
          :ok
          | {:error,
             :invalid_topic
             | :invalid_partition
             | :invalid_pid
             | :not_found
             | :partition_out_of_range}
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

        Agent.get_and_update(__MODULE__, fn %{topics: topics} = state ->
          case Map.fetch(topics, topic_key) do
            :error ->
              {{:error, :not_found}, state}

            {:ok, %{partition_count: count}} when partition_index >= count ->
              {{:error, :partition_out_of_range}, state}

            {:ok, %{owners: owners} = meta} ->
              updated_meta = %{meta | owners: Map.put(owners, partition_index, owner_pid)}
              {:ok, %{state | topics: Map.put(topics, topic_key, updated_meta)}}
          end
        end)
    end
  end

  @doc """
  Get the owner pid for a topic partition.

  Returns `{:ok, pid}` or `{:error, reason}` where reason may be
  `:invalid_topic | :invalid_partition | :not_found | :partition_out_of_range`.
  """
  @spec get_partition_owner(Types.topic(), Types.partition()) ::
          {:ok, pid()}
          | {:error, :invalid_topic | :invalid_partition | :not_found | :partition_out_of_range}
  def get_partition_owner(topic, partition) do
    cond do
      not Types.topic?(topic) ->
        {:error, :invalid_topic}

      not Types.partition?(partition) ->
        {:error, :invalid_partition}

      true ->
        topic_key = Types.topic_value(topic)
        partition_index = Types.partition_value(partition)

        Agent.get(__MODULE__, fn %{topics: topics} ->
          with {:ok, %{partition_count: count} = meta} <- Map.fetch(topics, topic_key),
               true <- partition_index < count || {:error, :partition_out_of_range},
               {:ok, pid} <- Map.fetch(meta.owners, partition_index) do
            {:ok, pid}
          else
            :error -> {:error, :not_found}
            {:error, reason} -> {:error, reason}
            _ -> {:error, :not_found}
          end
        end)
    end
  end
end
