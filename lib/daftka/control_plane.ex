defmodule Daftka.ControlPlane do
  @moduledoc """
  Top-level control plane supervisor for Daftka.

  Starts cluster, metadata, control plane APIs, and rebalancer.
  """

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(keyword()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}} | :ignore
  def init(_opts) do
    # Ensure only one control plane tree is active cluster-wide when distributed.
    if Node.alive?() do
      case Daftka.Global.register_unique({:daftka, :control_plane}) do
        true -> :ok
        :already_registered -> return_ignore()
      end
    end

    children = [
      # Metadata store and its raft group
      Daftka.Metadata.Supervisor,

      # Control plane APIs (skeletons)
      Daftka.MetadataAPI.Supervisor,
      Daftka.AdminAPI.Supervisor,

      # Rebalancer (singleton)
      Daftka.Rebalancer
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp return_ignore do
    # Make Supervisor.init return :ignore by short-circuiting via throw/catch
    throw({:ignore_control_plane, :already_running})
  catch
    {:ignore_control_plane, _} -> :ignore
  end
end
