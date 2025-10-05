import Config

if config_env() == :prod do
  port =
    System.get_env("DAFTKA_GATEWAY_PORT", "4001")
    |> String.to_integer()

  config :daftka, :gateway_port, port
end
