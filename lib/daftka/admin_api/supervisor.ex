defmodule Daftka.AdminAPI.Supervisor do
  @moduledoc """
  Supervisor for Admin API server (skeleton).
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: Daftka.Naming.via_global({:admin_api_supervisor}))
  end

  @impl true
  def init(_opts) do
    children = [
      Daftka.AdminAPI.Server
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
