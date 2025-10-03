defmodule Daftka.PartitionReplica.Server do
  @moduledoc """
  Partition replica server (skeleton).

  Will handle add/get and coordinate with storage.
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
