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
end
