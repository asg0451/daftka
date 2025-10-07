import Config

# Base application config

# Default gateway port; can be overridden per-environment or at runtime
config :daftka, :gateway_port, 4001

# Default roles: both control and data planes on a single node
config :daftka, :role, [:control_plane, :data_plane]
