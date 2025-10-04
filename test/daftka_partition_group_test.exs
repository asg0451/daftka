defmodule DaftkaPartitionGroupTest do
  use ExUnit.Case, async: false

  alias Daftka.PartitionReplica.Server, as: PartitionGroup
  alias Daftka.PartitionReplica.Supervisor, as: ReplicaSup
  alias Daftka.Partitions.Supervisor, as: Partitions
  alias Daftka.Types

  setup do
    id = {"topic-g", 0, 0}
    {:ok, pid} = Partitions.start_partition_replica_supervisor(id)

    on_exit(fn ->
      if Process.alive?(pid) do
        :ok = DynamicSupervisor.terminate_child(Partitions, pid)
      end
    end)

    {:ok, %{id: id, pid: pid}}
  end

  test "server and storage are registered via Registry", %{id: {topic, part, rep}} do
    server_via = ReplicaSup.server_name(topic, part, rep)
    storage_via = ReplicaSup.storage_name(topic, part, rep)

    assert is_pid(GenServer.whereis(server_via))
    assert is_pid(GenServer.whereis(storage_via))
  end

  test "next_offset proxies storage and append advances it", %{id: {topic, part, rep}} do
    server_via = ReplicaSup.server_name(topic, part, rep)

    o0 = PartitionGroup.next_offset(server_via)
    assert Types.offset_value(o0) == 0

    assert {:ok, o1} = PartitionGroup.append(server_via, "k1", "v1", %{"h" => "1"})
    assert Types.offset_value(o1) == 0

    o2 = PartitionGroup.next_offset(server_via)
    assert Types.offset_value(o2) == 1
  end

  test "fetch_from returns messages from storage", %{id: {topic, part, rep}} do
    server_via = ReplicaSup.server_name(topic, part, rep)

    assert {:ok, _} = PartitionGroup.append(server_via, "k1", "v1", %{"x" => "a"})
    assert {:ok, _} = PartitionGroup.append(server_via, "k2", "v2", %{"y" => "b"})
    assert {:ok, _} = PartitionGroup.append(server_via, "k3", "v3", %{"z" => "c"})

    {:ok, from1} = Types.new_offset(1)
    assert {:ok, msgs} = PartitionGroup.fetch_from(server_via, from1, 2)
    assert length(msgs) == 2

    [m1, m2] = msgs
    assert Types.message_key(m1) == "k2"
    assert Types.message_value(m1) == "v2"
    assert Types.offset_value(Types.message_offset(m1)) == 1
    assert Types.message_headers(m1) == %{"y" => "b"}

    assert Types.message_key(m2) == "k3"
    assert Types.offset_value(Types.message_offset(m2)) == 2
  end

  test "invalid append args propagate error", %{id: {topic, part, rep}} do
    server_via = ReplicaSup.server_name(topic, part, rep)

    assert {:error, :invalid_append_args} = PartitionGroup.append(server_via, :bad, "v", %{})
    assert {:error, :invalid_append_args} = PartitionGroup.append(server_via, "k", 1, %{})
    assert {:error, :invalid_append_args} = PartitionGroup.append(server_via, "k", "v", :bad)
  end

  test "invalid fetch args propagate error", %{id: {topic, part, rep}} do
    server_via = ReplicaSup.server_name(topic, part, rep)

    assert {:error, :invalid_fetch_args} = PartitionGroup.fetch_from(server_via, :bad, 10)

    {:ok, o0} = Types.new_offset(0)
    assert {:error, :invalid_fetch_args} = PartitionGroup.fetch_from(server_via, o0, 0)
  end
end
