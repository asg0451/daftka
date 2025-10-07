defmodule Daftka.Router.Supervisor do
  @moduledoc """
  Supervisor for the request router (skeleton).
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    _ = :gproc.reg(Daftka.Naming.key_global({:router_supervisor}))

    children = [
      Daftka.Router
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
