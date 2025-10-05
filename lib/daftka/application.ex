defmodule Daftka.Application do
  @moduledoc """
  OTP application entrypoint for Daftka.

  Starts an empty top-level supervisor for now.
  """

  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: Supervisor.on_start()
  def start(_type, _args) do
    enable_cp = Application.get_env(:daftka, :enable_control_plane, true)
    enable_dp = Application.get_env(:daftka, :enable_data_plane, true)

    children =
      [
        # Global registry for cross-plane naming
        {Registry, keys: :unique, name: Daftka.Registry}
      ]
      |> maybe_add(enable_cp, Daftka.ControlPlane)
      |> maybe_add(enable_dp, Daftka.DataPlane)

    opts = [strategy: :one_for_one, name: Daftka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add(children, true, child), do: children ++ [child]
  defp maybe_add(children, _falsey, _child), do: children
end
