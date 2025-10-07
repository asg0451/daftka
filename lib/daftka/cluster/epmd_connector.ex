defmodule Daftka.Cluster.EPMDConnector do
  @moduledoc """
  Minimal EPMD-based connector.

  Reads `DAFTKA_CONNECT_TO` env var (comma-separated node names) and
  periodically attempts `Node.connect/1` to each.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule()
    {:ok, %{peers: read_peers()}}
  end

  @impl true
  def handle_info(:tick, state) do
    Enum.each(state.peers, &safe_connect/1)
    schedule()
    {:noreply, state}
  end

  defp schedule, do: Process.send_after(self(), :tick, 1_000)

  defp read_peers do
    case System.get_env("DAFTKA_CONNECT_TO") do
      nil -> []
      str ->
        str
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(&String.to_atom/1)
    end
  end

  defp safe_connect(node_name) when is_atom(node_name) do
    _ = Node.connect(node_name)
    :ok
  end
end
