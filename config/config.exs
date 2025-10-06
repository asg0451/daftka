import Config

# Base application config

# Default gateway port; can be overridden per-environment or at runtime
config :daftka, :gateway_port, 4001

# Node roles (can be overridden by env in runtime.exs via DAFTKA_ROLES)
config :daftka, :roles, [:control_plane, :data_plane]
