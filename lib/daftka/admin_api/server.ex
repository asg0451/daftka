defmodule Daftka.AdminAPI.Server do
  @moduledoc """
  Admin API server (skeleton).

  Will provide drain/add-node/reassign endpoints.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Daftka.Naming.via_global({:admin_api}))
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end
end
