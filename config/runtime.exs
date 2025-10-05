import Config

# Allow overriding gateway port via env in any environment
if port = System.get_env("DAFTKA_GATEWAY_PORT") do
  config :daftka, :gateway_port, String.to_integer(port)
end

# Plane toggles via env
if cp = System.get_env("DAFTKA_ENABLE_CP") do
  config :daftka, :enable_control_plane, cp in ["1", "true", "TRUE"]
end

if dp = System.get_env("DAFTKA_ENABLE_DP") do
  config :daftka, :enable_data_plane, dp in ["1", "true", "TRUE"]
end
