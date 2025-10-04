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
            required(:topics) => %{required(String.t()) => %{partition_count: pos_integer()}}
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
          updated_topics = Map.put(topics, topic_key, %{partition_count: partition_count})
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

  Returns `{:ok, meta}` or `{:error, :invalid_topic | :not_found}`.
  """
  @spec get_topic(Types.topic()) ::
          {:ok, %{partition_count: pos_integer()}} | {:error, :invalid_topic | :not_found}
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
  @spec list_topics() :: [{Types.topic(), %{partition_count: pos_integer()}}]
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
end
