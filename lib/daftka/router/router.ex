defmodule Daftka.Router do
  @moduledoc """
  Request router (skeleton).

  Will route requests to the current partition leader using metadata.
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
