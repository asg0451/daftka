defmodule Daftka.Metadata.Supervisor do
  @moduledoc """
  Supervisor for the metadata subsystem (skeleton).

  Intended to run a raft group and a KV server, but empty for now.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Daftka.Metadata.Raft,
      # Daftka.Metadata.KV
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
