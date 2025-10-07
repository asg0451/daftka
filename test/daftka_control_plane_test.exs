defmodule DaftkaControlPlaneTest do
  use ExUnit.Case, async: false

  test "control plane supervisor starts and control-plane processes are present" do
    assert :gproc.where(Daftka.Naming.key_global({:control_plane}))
    assert :gproc.where(Daftka.Naming.key_global({:cluster_supervisor}))
    assert Process.whereis(Daftka.Metadata.Supervisor)
    assert :gproc.where(Daftka.Naming.key_global({:metadata_api_supervisor}))
    assert :gproc.where(Daftka.Naming.key_global({:admin_api_supervisor}))
    assert :gproc.where(Daftka.Naming.key_global({:rebalancer}))
  end
end
