defmodule Daftka.Application do
  @moduledoc """
  OTP application entrypoint for Daftka.

  Starts an empty top-level supervisor for now.
  """

  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: Supervisor.on_start()
  def start(_type, _args) do
    children = [
      # Global registry for cross-plane naming
      {Registry, keys: :unique, name: Daftka.Registry},

      # Control plane and data plane supervisors
      Daftka.ControlPlane,
      Daftka.DataPlane
    ]

    opts = [strategy: :one_for_one, name: Daftka.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
