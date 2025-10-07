defmodule Daftka.ControlPlane do
  @moduledoc """
  Top-level control plane supervisor for Daftka.

  Starts cluster, metadata, control plane APIs, and rebalancer.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: Daftka.Naming.via_global({:control_plane}))
  end

  @impl true
  @spec init(keyword()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}} | :ignore
  def init(_opts) do
    children = [
      # Cluster membership and node strategy
      Daftka.Cluster.Supervisor,

      # Metadata store and its raft group
      Daftka.Metadata.Supervisor,

      # Control plane APIs (skeletons)
      Daftka.MetadataAPI.Supervisor,
      Daftka.AdminAPI.Supervisor,

      # Rebalancer (singleton)
      Daftka.Rebalancer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
