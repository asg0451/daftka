defmodule Daftka.PartitionReplica.Storage do
  @moduledoc """
  Storage process for a single topic-partition (skeleton).

  In MVP this will be an in-memory KV; initially no functionality.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
end
