defmodule Daftka.DataPlane do
  @moduledoc """
  Top-level data plane supervisor for Daftka.

  Starts router, HTTP gateway, and dynamic partitions supervisor.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: Daftka.Naming.via_global({:data_plane}))
  end

  @impl true
  def init(_opts) do
    children = [
      Daftka.Router.Supervisor,
      Daftka.Gateway.Supervisor,
      Daftka.Partitions.Supervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
