defmodule DaftkaRebalancerTest do
  use ExUnit.Case, async: false

  alias Daftka.Metadata.Store
  alias Daftka.Types

  setup do
    assert Process.whereis(Daftka.Rebalancer)
    assert Process.whereis(Daftka.Partitions.Supervisor)
    assert Process.whereis(Store)
    Store.clear()
    :ok
  end

  defp eventually(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1_500)
    interval = Keyword.get(opts, :interval, 25)

    start = System.monotonic_time(:millisecond)

    do_eventually(fun, start, timeout, interval)
  end

  defp do_eventually(fun, start, timeout, interval) do
    case fun.() do
      {:ok, value} ->
        value

      value when value not in [nil, false] ->
        value

      _ ->
        now = System.monotonic_time(:millisecond)

        if now - start > timeout do
          flunk("eventually/2 timed out after #{timeout} ms")
        else
          Process.sleep(interval)
          do_eventually(fun, start, timeout, interval)
        end
    end
  end

  test "rebalancer spawns partition replica supervisor and sets owner for new topic" do
    {:ok, topic} = Types.new_topic("rebalance-topic-1")
    {:ok, p0} = Types.new_partition(0)

    :ok = Store.create_topic(topic)

    via =
      {:via, Registry,
       {Daftka.Registry, {:partition_replica_supervisor, "rebalance-topic-1", 0, 0}}}

    pid = eventually(fn -> GenServer.whereis(via) end)
    assert is_pid(pid) and Process.alive?(pid)

    assert {:ok, ^pid} = Store.get_partition_owner(topic, p0)
  end

  test "rebalancer recreates supervisor and updates owner if supervisor stops" do
    {:ok, topic} = Types.new_topic("rebalance-topic-2")
    {:ok, p0} = Types.new_partition(0)

    :ok = Store.create_topic(topic)

    via =
      {:via, Registry,
       {Daftka.Registry, {:partition_replica_supervisor, "rebalance-topic-2", 0, 0}}}

    old_pid = eventually(fn -> GenServer.whereis(via) end)
    assert {:ok, ^old_pid} = Store.get_partition_owner(topic, p0)

    # Stop the child; DynamicSupervisor will not auto-restart on manual terminate
    :ok = DynamicSupervisor.terminate_child(Daftka.Partitions.Supervisor, old_pid)
    eventually(fn -> if GenServer.whereis(via) == nil, do: true, else: nil end)

    # Rebalancer should start it again
    new_pid = eventually(fn -> GenServer.whereis(via) end)
    assert is_pid(new_pid) and new_pid != old_pid

    assert {:ok, ^new_pid} = Store.get_partition_owner(topic, p0)
  end
end
