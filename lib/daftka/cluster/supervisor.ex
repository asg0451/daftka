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
    # No children for now; gproc is started by its application
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end
