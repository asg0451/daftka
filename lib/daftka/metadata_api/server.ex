defmodule Daftka.MetadataAPI.Server do
  @moduledoc """
  Metadata API server (skeleton).

  Will expose control-plane operations (e.g., CreateTopic).
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
