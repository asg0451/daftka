defmodule Daftka.Cluster.Supervisor do
  @moduledoc """
  Cluster membership supervisor (skeleton).

  In the future this will manage libcluster or a static strategy.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    alias Cluster.Supervisor, as: LibclusterSupervisor

    children = [
      {LibclusterSupervisor, [topologies(), [name: Daftka.Cluster.LibclusterSupervisor]]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Build a libcluster topology using EPMD and a comma-separated list of node names
  # from the DAFTKA_CLUSTER_HOSTS environment variable, e.g.
  #   DAFTKA_CLUSTER_HOSTS="daftka1@127.0.0.1,daftka2@127.0.0.1"
  defp topologies do
    hosts =
      System.get_env("DAFTKA_CLUSTER_HOSTS", "")
      |> String.split([",", " ", "\n", "\t"], trim: true)
      |> Enum.map(&String.to_atom/1)

    [
      daftka_epmd: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: hosts],
        connect: {:net_kernel, :connect_node, []},
        disconnect: {:erlang, :disconnect_node, []},
        list_nodes: {:erlang, :nodes, [:connected]}
      ]
    ]
  end
end
