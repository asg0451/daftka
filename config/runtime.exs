import Config

port =
  System.get_env(
    "DAFTKA_GATEWAY_PORT",
    to_string(Application.get_env(:daftka, :gateway_port, 4001))
  )
  |> String.to_integer()

config :daftka, :gateway_port, port

# Roles from env: comma-separated values, e.g. "control_plane,data_plane".
roles_env = System.get_env("DAFTKA_ROLES")

roles =
  case roles_env do
    nil ->
      Application.get_env(:daftka, :roles, [:control_plane, :data_plane])

    roles_str when is_binary(roles_str) ->
      roles_str
      |> String.split([",", " "], trim: true)
      |> Enum.map(fn s ->
        case String.trim(s) do
          "control_plane" ->
            :control_plane

          "data_plane" ->
            :data_plane

          other ->
            IO.warn("Ignoring unknown role '#{other}' in DAFTKA_ROLES")
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
  end

config :daftka, :roles, roles
