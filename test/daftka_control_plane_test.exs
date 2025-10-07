defmodule DaftkaControlPlaneTest do
  use ExUnit.Case, async: false

  test "control plane supervisor starts and control-plane processes are present" do
    assert Process.whereis(Daftka.Naming.via_global({:control_plane}))

    assert Process.whereis(Daftka.Naming.via_global({:cluster_supervisor}))
    assert Process.whereis(Daftka.Metadata.Supervisor)
    assert Process.whereis(Daftka.Naming.via_global({:metadata_api_supervisor}))
    assert Process.whereis(Daftka.Naming.via_global({:admin_api_supervisor}))
    assert Process.whereis(Daftka.Naming.via_global({:rebalancer}))
  end
end
