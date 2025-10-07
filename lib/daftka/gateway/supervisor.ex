defmodule Daftka.Gateway.Supervisor do
  @moduledoc """
  Supervisor for HTTP API gateway (skeleton).
  """

  use Supervisor
  require Logger

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: Daftka.Naming.via_global({:gateway_supervisor}))
  end

  @impl true
  def init(_opts) do
    port = Application.get_env(:daftka, :gateway_port, 4001)

    Logger.info("Starting HTTP gateway on port #{port}")

    # Name the Ranch listener via :ref so we can assert on it in tests
    children = [
      {Plug.Cowboy,
       scheme: :http, plug: Daftka.Gateway.Server, options: [port: port, ref: Daftka.Gateway.HTTP]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
