defmodule Daftka.Gateway.Server do
  @moduledoc """
  HTTP API Gateway (skeleton).

  Placeholder process; no HTTP server wired yet.
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
