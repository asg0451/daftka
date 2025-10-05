defmodule DaftkaRouterTest do
  use ExUnit.Case, async: false

  alias Daftka.Metadata.Store
  alias Daftka.PartitionReplica.Supervisor, as: PartSup
  alias Daftka.Partitions.Supervisor, as: Partitions
  alias Daftka.Router
  alias Daftka.Types

  setup do
    # ensure metadata clean
    Store.clear()

    # create topic with two partitions
    {:ok, topic} = Types.new_topic("routed")
    :ok = Store.create_topic(topic, 2)

    # start partition supervisors and record owners via Store
    {:ok, pid0} = Partitions.start_partition_supervisor({"routed", 0})
    {:ok, pid1} = Partitions.start_partition_supervisor({"routed", 1})

    on_exit(fn ->
      if Process.alive?(pid0), do: DynamicSupervisor.terminate_child(Partitions, pid0)
      if Process.alive?(pid1), do: DynamicSupervisor.terminate_child(Partitions, pid1)
    end)

    server0 = PartSup.server_name("routed", 0)
    server1 = PartSup.server_name("routed", 1)

    {:ok, p0} = Types.new_partition(0)
    {:ok, p1} = Types.new_partition(1)

    :ok = Store.set_partition_owner(topic, p0, GenServer.whereis(server0))
    :ok = Store.set_partition_owner(topic, p1, GenServer.whereis(server1))

    {:ok, %{topic: topic, p0: p0, p1: p1}}
  end

  test "route returns owner pid", %{topic: topic, p0: p0} do
    assert {:ok, pid} = Router.route(topic, p0)
    assert is_pid(pid)
  end

  test "produce delegates to partition server and advances offset", %{topic: topic, p0: p0} do
    assert {:ok, o0} = Router.produce(topic, p0, "k1", "v1", %{"h" => "1"})
    assert Types.offset_value(o0) == 0

    assert {:ok, next} = Router.next_offset(topic, p0)
    assert Types.offset_value(next) == 1
  end

  test "fetch_from delegates and returns messages", %{topic: topic, p0: p0} do
    assert {:ok, _} = Router.produce(topic, p0, "k1", "v1", %{"x" => "a"})
    assert {:ok, _} = Router.produce(topic, p0, "k2", "v2", %{"y" => "b"})
    assert {:ok, _} = Router.produce(topic, p0, "k3", "v3", %{"z" => "c"})

    {:ok, from1} = Types.new_offset(1)
    assert {:ok, msgs} = Router.fetch_from(topic, p0, from1, 2)
    assert length(msgs) == 2

    [m1, m2] = msgs
    assert m1.key == "k2"
    assert m1.value == "v2"
    assert Types.offset_value(m1.offset) == 1
    assert m1.headers == %{"y" => "b"}

    assert m2.key == "k3"
    assert Types.offset_value(m2.offset) == 2
  end

  test "errors bubble when topic or partition invalid" do
    # invalid constructors
    assert {:error, :invalid_topic} = Router.route("bad", 0)
    assert {:error, :invalid_partition} = Router.route(elem(Types.new_topic("x"), 1), -1)
  end

  test "not_found when no owner recorded", %{p1: p1} do
    {:ok, topic2} = Types.new_topic("empty")
    :ok = Store.create_topic(topic2, 2)

    assert {:error, :not_found} = Router.route(topic2, p1)
  end
end
