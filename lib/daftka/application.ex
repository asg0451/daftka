defmodule Daftka.Application do
  @moduledoc """
  OTP application entrypoint for Daftka.

  Starts an empty top-level supervisor for now.
  """

  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: Supervisor.on_start()
  def start(_type, _args) do
    roles = Application.get_env(:daftka, :role, [:control_plane, :data_plane])

    # Ensure gproc is started (should be in extra_applications too)
    _ = :gproc.start_link()

    children =
      role_children(roles)

    opts = [strategy: :one_for_one, name: Daftka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @spec role_children([:control_plane | :data_plane | :http_gateway]) :: [Supervisor.child_spec()]
  defp role_children(roles) do
    roles_set = MapSet.new(roles)
    children = []

    children = if :control_plane in roles_set, do: children ++ [Daftka.ControlPlane], else: children
    children = if :data_plane in roles_set, do: children ++ [Daftka.DataPlane], else: children
    # Only add standalone gateway if data_plane is NOT present
    children =
      if :http_gateway in roles_set and not (:data_plane in roles_set) do
        children ++ [Daftka.Gateway.Supervisor]
      else
        children
      end

    children
  end

  # legacy helper retained for readability during refactors
  defp maybe_add(children, _roles, _role, _child), do: children
end
