defmodule DaftkaRebalancerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Daftka.Metadata.Store
  alias Daftka.MetadataAPI.Server, as: MetadataAPI
  alias Daftka.PartitionReplica.Supervisor, as: PartSup
  # alias retained for clarity of intent
  alias Daftka.Types

  setup do
    assert :gproc.where(Daftka.Naming.key_global({:rebalancer}))
    Store.clear()
    :ok
  end

  test "spawns partition supervisors and records owners for all partitions" do
    :ok = MetadataAPI.create_topic("reb-a", 3)

    # Allow a couple polls
    Process.sleep(150)

    for idx <- 0..2 do
      via = PartSup.supervisor_name("reb-a", idx)
      sup_pid = GenServer.whereis(via)
      assert is_pid(sup_pid)
      assert Process.alive?(sup_pid)
    end

    {:ok, [{typed_topic, _} | _]} =
      case Store.list_topics() do
        [] -> {:ok, []}
        list -> {:ok, list}
      end

    for idx <- 0..2 do
      {:ok, p} = Types.new_partition(idx)
      {:ok, owner} = Store.get_partition_owner(typed_topic, p)
      assert is_pid(owner)
      assert Process.alive?(owner)
    end
  end

  test "idempotent reconciliation does not crash or duplicate" do
    :ok = MetadataAPI.create_topic("reb-b", 2)
    Process.sleep(150)

    # Trigger manual reconcile by sending poll
    _log =
      capture_log(fn ->
        if pid = Process.whereis(Daftka.Rebalancer) do
          send(pid, :poll)
        end

        Process.sleep(50)
      end)

    for idx <- 0..1 do
      via = PartSup.supervisor_name("reb-b", idx)
      sup_pid = GenServer.whereis(via)
      assert is_pid(sup_pid)
      assert Process.alive?(sup_pid)
    end
  end
end
