defmodule Daftka.AdminAPI.Supervisor do
  @moduledoc """
  Supervisor for Admin API server (skeleton).
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    _ = :gproc.reg(Daftka.Naming.key_global({:admin_api_supervisor}))
    children = [
      Daftka.AdminAPI.Server
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
