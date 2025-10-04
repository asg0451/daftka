defmodule DaftkaDataPlaneTest do
  use ExUnit.Case, async: false

  test "data plane supervisor starts and data-plane processes are present" do
    assert Process.whereis(Daftka.DataPlane)
    assert Process.whereis(Daftka.Router.Supervisor)
    assert Process.whereis(Daftka.Gateway.Supervisor)
    assert Process.whereis(Daftka.Partitions.Supervisor)
  end

  test "router and gateway servers are running" do
    assert Process.whereis(Daftka.Router)
    assert Process.whereis(Daftka.Gateway.Server)
  end
end
