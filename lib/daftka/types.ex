defmodule Daftka.Types do
  @moduledoc """
  Base opaque types and constructors for Daftka domain primitives.

  Exposes strongly-typed wrappers for topics, partitions, and offsets.
  The underlying representation is intentionally opaque to callers.
  """

  # Topic
  defmodule Topic do
    @moduledoc false
    @enforce_keys [:value]
    defstruct [:value]
  end

  @opaque topic :: %Topic{value: String.t()}
  @type topic_error :: {:error, :invalid_topic}

  @doc """
  Construct a topic.

  Rules:
  - Non-empty UTF-8 binary
  - Trimmed value must be non-empty
  """
  @spec new_topic(term()) :: {:ok, topic} | topic_error
  def new_topic(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, :invalid_topic}
    else
      {:ok, %Topic{value: trimmed}}
    end
  end

  def new_topic(_), do: {:error, :invalid_topic}

  @doc """
  Extract the underlying topic name.
  """
  @spec topic_value(topic) :: String.t()
  def topic_value(%Topic{value: value}), do: value

  # Partition
  defmodule Partition do
    @moduledoc false
    @enforce_keys [:value]
    defstruct [:value]
  end

  @opaque partition :: %Partition{value: non_neg_integer()}
  @type partition_error :: {:error, :invalid_partition}

  @doc """
  Construct a partition index (0-based).
  """
  @spec new_partition(term()) :: {:ok, partition} | partition_error
  def new_partition(value) when is_integer(value) and value >= 0 do
    {:ok, %Partition{value: value}}
  end

  def new_partition(_), do: {:error, :invalid_partition}

  @doc """
  Extract the underlying partition index.
  """
  @spec partition_value(partition) :: non_neg_integer()
  def partition_value(%Partition{value: value}), do: value

  # Offset
  defmodule Offset do
    @moduledoc false
    @enforce_keys [:value]
    defstruct [:value]
  end

  @opaque offset :: %Offset{value: non_neg_integer()}
  @type offset_error :: {:error, :invalid_offset}

  @doc """
  Construct an offset (monotonic, 0-based).
  """
  @spec new_offset(term()) :: {:ok, offset} | offset_error
  def new_offset(value) when is_integer(value) and value >= 0 do
    {:ok, %Offset{value: value}}
  end

  def new_offset(_), do: {:error, :invalid_offset}

  @doc """
  Extract the underlying offset value.
  """
  @spec offset_value(offset) :: non_neg_integer()
  def offset_value(%Offset{value: value}), do: value

  # Predicates
  @doc """
  Returns true if the term is a `t:topic/0`.
  """
  @spec topic?(term()) :: boolean()
  def topic?(%Topic{}), do: true
  def topic?(_), do: false

  @doc """
  Returns true if the term is a `t:partition/0`.
  """
  @spec partition?(term()) :: boolean()
  def partition?(%Partition{}), do: true
  def partition?(_), do: false

  @doc """
  Returns true if the term is a `t:offset/0`.
  """
  @spec offset?(term()) :: boolean()
  def offset?(%Offset{}), do: true
  def offset?(_), do: false
end
