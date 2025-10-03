defmodule Daftka.ControlPlane do
  @moduledoc """
  Top-level control plane supervisor for Daftka.

  Starts cluster, metadata, router, gateway, APIs, rebalancer, and partitions supervisors.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(keyword()) :: {:ok, Supervisor.sup_flags(), [Supervisor.child_spec()]}
  def init(_opts) do
    children = [
      # Global registry for named processes (unique keys)
      {Registry, keys: :unique, name: Daftka.Registry},

      # Cluster membership and node strategy
      Daftka.Cluster.Supervisor,

      # Metadata store and its raft group
      Daftka.Metadata.Supervisor,

      # Request Router
      Daftka.Router.Supervisor,

      # HTTP Gateway for data plane and control plane APIs (skeletons)
      Daftka.Gateway.Supervisor,

      # Control plane APIs (skeletons)
      Daftka.MetadataAPI.Supervisor,
      Daftka.AdminAPI.Supervisor,

      # Rebalancer (singleton)
      Daftka.Rebalancer,

      # Dynamic supervisor managing all partition replicas on this node
      Daftka.Partitions.Supervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
