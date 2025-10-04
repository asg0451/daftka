defmodule DaftkaSkeletonsTest do
  use ExUnit.Case, async: false

  test "control plane supervisor starts and control-plane processes are present" do
    assert Process.whereis(Daftka.ControlPlane)

    # Ensure control plane supervisors/servers are alive
    assert Process.whereis(Daftka.Cluster.Supervisor)
    assert Process.whereis(Daftka.Metadata.Supervisor)
    assert Process.whereis(Daftka.MetadataAPI.Supervisor)
    assert Process.whereis(Daftka.AdminAPI.Supervisor)
    assert Process.whereis(Daftka.Rebalancer)
  end

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

  test "dynamic supervisor can start and stop a partition replica supervisor" do
    id = {"topic-a", 0, 1}

    {:ok, pid} = Daftka.Partitions.Supervisor.start_partition_replica_supervisor(id)
    assert is_pid(pid)
    assert Process.alive?(pid)

    # Locate via registry name
    via = {:via, Registry, {Daftka.Registry, {:partition_replica_supervisor, "topic-a", 0, 1}}}
    assert pid == GenServer.whereis(via)

    # Stop it
    :ok = DynamicSupervisor.terminate_child(Daftka.Partitions.Supervisor, pid)
    refute Process.alive?(pid)
  end
end
