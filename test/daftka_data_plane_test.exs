defmodule DaftkaDataPlaneTest do
  use ExUnit.Case, async: false

  test "data plane supervisor starts and data-plane processes are present" do
    assert Process.whereis(Daftka.Naming.via_global({:data_plane}))
    assert Process.whereis(Daftka.Router.Supervisor)
    assert Process.whereis(Daftka.Gateway.Supervisor)
    assert Process.whereis(Daftka.Partitions.Supervisor)
  end

  test "router and gateway servers are running" do
    assert Process.whereis(Daftka.Naming.via_global({:router}))
    # assert Ranch listener child exists under gateway supervisor (named via :ref)
    children = Supervisor.which_children(Daftka.Gateway.Supervisor)

    assert Enum.any?(children, fn
             {{:ranch_embedded_sup, Daftka.Gateway.HTTP}, _pid, :supervisor,
              [:ranch_embedded_sup]} ->
               true

             _ ->
               false
           end)
  end
end
