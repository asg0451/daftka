defmodule Daftka.Rebalancer do
  @moduledoc """
  Rebalancer singleton process (skeleton).

  Will monitor metadata and manage partition replica placement.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
end
