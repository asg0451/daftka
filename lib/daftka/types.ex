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

  # Message
  defmodule Message do
    @moduledoc false
    @enforce_keys [:offset, :key, :value, :headers]
    defstruct [:offset, :key, :value, :headers]
  end

  @type header_value :: binary()
  @type headers :: %{optional(String.t()) => header_value}

  @type message :: %Message{
          offset: offset,
          key: binary(),
          value: binary(),
          headers: headers
        }

  @type message_error ::
          {:error, :invalid_message_offset}
          | {:error, :invalid_message_key}
          | {:error, :invalid_message_value}
          | {:error, :invalid_message_headers}

  @doc """
  Construct a message value with validated fields.

  - `offset` must be a valid `t:offset/0`
  - `key` and `value` must be binaries
  - `headers` is a map of binary keys to binary values
  """
  @spec new_message(offset, term(), term(), term()) :: {:ok, message} | message_error
  def new_message(%Offset{} = offset, key, value, headers) do
    cond do
      not is_binary(key) -> {:error, :invalid_message_key}
      not is_binary(value) -> {:error, :invalid_message_value}
      not valid_headers?(headers) -> {:error, :invalid_message_headers}
      true -> {:ok, %Message{offset: offset, key: key, value: value, headers: headers}}
    end
  end

  def new_message(_, _, _, _), do: {:error, :invalid_message_offset}

  defp valid_headers?(headers) when is_map(headers) do
    Enum.all?(headers, fn
      {k, v} when is_binary(k) and is_binary(v) -> true
      _ -> false
    end)
  end

  defp valid_headers?(_), do: false
end
