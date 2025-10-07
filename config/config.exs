import Config

# Base application config

# Default gateway port; can be overridden per-environment or at runtime
config :daftka, :gateway_port, 4001

# Node roles: control_plane, data_plane, or both.
# Default to both in dev/test for simplicity; override via env or runtime.exs.
config :daftka, :roles, [:control_plane, :data_plane]

# HTTP gateway topology: :single | :multi_node
config :daftka, :gateway_topology, :single
