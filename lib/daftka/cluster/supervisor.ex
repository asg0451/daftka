defmodule Daftka.Cluster.Supervisor do
  @moduledoc """
  Cluster membership supervisor (skeleton).

  In the future this will manage libcluster or a static strategy.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: Daftka.Naming.via_global({:cluster_supervisor}))
  end

  @impl true
  def init(_opts) do
    children = [
      # EPMD connector to ensure we can form a small static cluster via env
      {Daftka.Cluster.EPMDConnector, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
