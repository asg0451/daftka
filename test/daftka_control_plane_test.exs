defmodule DaftkaControlPlaneTest do
  use ExUnit.Case, async: false

  test "control plane supervisor starts and control-plane processes are present" do
    assert Process.whereis(Daftka.ControlPlane)

    assert Process.whereis(Daftka.Cluster.Supervisor)
    assert Process.whereis(Daftka.Metadata.Supervisor)
    assert Process.whereis(Daftka.MetadataAPI.Supervisor)
    assert Process.whereis(Daftka.AdminAPI.Supervisor)
    pid = Process.whereis(Daftka.Rebalancer) || :swarm.whereis_name(Daftka.Rebalancer)
    assert is_pid(pid)
  end
end
