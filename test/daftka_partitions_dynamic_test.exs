defmodule DaftkaPartitionsDynamicTest do
  use ExUnit.Case, async: false

  test "dynamic supervisor can start and stop a partition supervisor" do
    id = {"topic-a", 0}

    {:ok, pid} = Daftka.Partitions.Supervisor.start_partition_supervisor(id)
    assert is_pid(pid)
    assert Process.alive?(pid)

    via = Daftka.Naming.partition_supervisor_via("topic-a", 0)
    assert pid == GenServer.whereis(via)

    :ok = DynamicSupervisor.terminate_child(Daftka.Partitions.Supervisor, pid)
    refute Process.alive?(pid)
  end
end
