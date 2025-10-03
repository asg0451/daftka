defmodule Daftka.Application do
  @moduledoc """
  OTP application entrypoint for Daftka.

  Starts an empty top-level supervisor for now.
  """

  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: Supervisor.on_start()
  def start(_type, _args) do
    children = []

    opts = [strategy: :one_for_one, name: Daftka.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
