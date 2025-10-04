defmodule Daftka.PartitionReplica.Server do
  @moduledoc """
  Partition replica server (skeleton).

  Will handle add/get and coordinate with storage.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    case Keyword.get(opts, :name) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
end
