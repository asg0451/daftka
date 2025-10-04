defmodule Daftka.PartitionReplica.Storage do
  @moduledoc """
  In-memory append-only log storage for a single topic-partition.

  Maintains a list of messages and a monotonic offset counter.
  Offsets are 0-based and strictly increasing.
  """

  use GenServer

  alias Daftka.Types

  @opaque state :: %{messages: [Types.message()], next_offset: non_neg_integer()}

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    case Keyword.get(opts, :name) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc """
  Append a message with provided key, value, and headers.

  Returns `{:ok, offset}` where `offset` is a `Types.offset/0` of the appended message.
  """
  @spec append(GenServer.server(), binary(), binary(), Types.headers()) ::
          {:ok, Types.offset()} | {:error, term()}
  def append(server \\ __MODULE__, key, value, headers \\ %{}) do
    GenServer.call(server, {:append, key, value, headers})
  end

  @doc """
  Fetch messages starting from `from_offset` (inclusive) up to `max_count` messages.
  Returns `{:ok, [Types.message()]}`.
  """
  @spec fetch_from(GenServer.server(), Types.offset(), pos_integer()) ::
          {:ok, [Types.message()]} | {:error, term()}
  def fetch_from(server \\ __MODULE__, from_offset, max_count)

  def fetch_from(server, from_offset, max_count)
      when is_integer(max_count) and max_count > 0 do
    if Types.offset?(from_offset) do
      start_index = Types.offset_value(from_offset)
      GenServer.call(server, {:fetch_from_index, start_index, max_count})
    else
      {:error, :invalid_fetch_args}
    end
  end

  def fetch_from(_server, _bad_offset, _max_count), do: {:error, :invalid_fetch_args}

  @doc """
  Return the current high-water mark (next offset to be written).
  """
  @spec next_offset(GenServer.server()) :: Types.offset()
  def next_offset(server \\ __MODULE__) do
    GenServer.call(server, :next_offset)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{messages: [], next_offset: 0}}
  end

  @impl true
  def handle_call(:next_offset, _from, %{next_offset: next} = state) do
    {:reply, elem(Types.new_offset(next), 1), state}
  end

  def handle_call(
        {:append, key, value, headers},
        _from,
        %{messages: messages, next_offset: next} = state
      )
      when is_binary(key) and is_binary(value) and is_map(headers) do
    {:ok, offset} = Types.new_offset(next)
    {:ok, message} = Types.new_message(offset, key, value, headers)

    new_state = %{state | messages: messages ++ [message], next_offset: next + 1}
    {:reply, {:ok, offset}, new_state}
  end

  def handle_call({:append, _key, _value, _headers}, _from, state) do
    {:reply, {:error, :invalid_append_args}, state}
  end

  def handle_call(
        {:fetch_from_index, start_index, max_count},
        _from,
        %{messages: messages} = state
      )
      when is_integer(start_index) and start_index >= 0 and is_integer(max_count) and
             max_count > 0 do
    sliced = messages |> Enum.drop(start_index) |> Enum.take(max_count)
    {:reply, {:ok, sliced}, state}
  end

  def handle_call({:fetch_from_index, _offset, _max_count}, _from, state) do
    {:reply, {:error, :invalid_fetch_args}, state}
  end
end
