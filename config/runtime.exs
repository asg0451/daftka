import Config

# Allow overriding gateway port via env in any environment
if port = System.get_env("DAFTKA_GATEWAY_PORT") do
  config :daftka, :gateway_port, String.to_integer(port)
end

# Roles via env: comma-separated list of atoms, e.g. "control_plane,data_plane"
if roles_str = System.get_env("DAFTKA_ROLES") do
  roles =
    roles_str
    |> String.split([",", " ", "\n", "\t"], trim: true)
    |> Enum.map(fn s -> String.trim_leading(s, ":") |> String.to_atom() end)

  config :daftka, :roles, roles
end
