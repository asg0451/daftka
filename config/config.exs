import Config

# Base application config

# Default gateway port; can be overridden per-environment or at runtime
config :daftka, :gateway_port, 4001

# Plane toggles (can be overridden by env in runtime.exs)
config :daftka, :enable_control_plane, true
config :daftka, :enable_data_plane, true
