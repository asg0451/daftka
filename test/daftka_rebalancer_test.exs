defmodule DaftkaRebalancerTest do
  use ExUnit.Case, async: false

  alias Daftka.Metadata.Store
  alias Daftka.MetadataAPI.Server, as: MetadataAPI
  alias Daftka.PartitionReplica.Supervisor, as: PartSup
  alias Daftka.Rebalancer
  alias Daftka.Types

  setup do
    assert Process.whereis(Rebalancer)
    Store.clear()
    :ok
  end

  test "spawns partition supervisor and records owner for partition 0" do
    :ok = MetadataAPI.create_topic("reb-a")

    # Allow a couple polls
    Process.sleep(150)

    via = PartSup.supervisor_name("reb-a", 0)
    sup_pid = GenServer.whereis(via)
    assert is_pid(sup_pid)
    assert Process.alive?(sup_pid)

    {:ok, [{typed_topic, _} | _]} =
      case Store.list_topics() do
        [] -> {:ok, []}
        list -> {:ok, list}
      end

    {:ok, p0} = Types.new_partition(0)
    {:ok, owner} = Store.get_partition_owner(typed_topic, p0)
    assert is_pid(owner)
    assert Process.alive?(owner)
  end

  test "idempotent reconciliation does not crash or duplicate" do
    :ok = MetadataAPI.create_topic("reb-b")
    Process.sleep(150)

    # Trigger manual reconcile by sending poll
    send(Rebalancer, :poll)
    Process.sleep(50)

    via = PartSup.supervisor_name("reb-b", 0)
    sup_pid = GenServer.whereis(via)
    assert is_pid(sup_pid)
    assert Process.alive?(sup_pid)
  end
end
