defmodule Daftka.Application do
  @moduledoc """
  OTP application entrypoint for Daftka.

  Starts an empty top-level supervisor for now.
  """

  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: Supervisor.on_start()
  def start(_type, _args) do
    # Only set cookie if node is alive (distributed). In tests, node is :nonode@nohost.
    if Node.alive?() do
      cookie =
        case System.get_env("DAFTKA_COOKIE") do
          nil -> :daftka
          val -> String.to_atom(val)
        end

      :erlang.set_cookie(node(), cookie)
    end

    roles = Application.get_env(:daftka, :roles, [:control_plane, :data_plane])

    children =
      [
        # Global registry (local), used for local via names; cross-node will use gproc
        {Registry, keys: :unique, name: Daftka.Registry}
      ]
      |> maybe_add(:control_plane, roles, Daftka.ControlPlane)
      |> maybe_add(:data_plane, roles, Daftka.DataPlane)

    opts = [strategy: :one_for_one, name: Daftka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add(list, role, roles, child) do
    if role in roles, do: list ++ [child], else: list
  end
end
