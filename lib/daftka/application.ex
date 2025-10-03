defmodule Daftka.Application do
  @moduledoc """
  Application supervision entrypoint for Daftka.

  This starts the top-level supervisor with no children yet. Subsequent
  tasks will add supervisors and workers under this root.
  """

  use Application

  @impl true
  @spec start(Application.start_type(), term()) ::
          {:ok, pid()} | {:error, {:already_started, pid()} | term()}
  def start(_type, _args) do
    children = [
      # Intentionally empty; populated in subsequent tasks
    ]

    opts = [strategy: :one_for_one, name: Daftka.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
