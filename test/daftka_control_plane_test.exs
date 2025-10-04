defmodule DaftkaControlPlaneTest do
  use ExUnit.Case, async: false

  test "control plane supervisor starts and control-plane processes are present" do
    assert Process.whereis(Daftka.ControlPlane)

    assert Process.whereis(Daftka.Cluster.Supervisor)
    assert Process.whereis(Daftka.Metadata.Supervisor)
    assert Process.whereis(Daftka.MetadataAPI.Supervisor)
    assert Process.whereis(Daftka.AdminAPI.Supervisor)
    assert Process.whereis(Daftka.Rebalancer)
  end
end
