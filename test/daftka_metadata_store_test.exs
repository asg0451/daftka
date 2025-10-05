defmodule DaftkaMetadataStoreTest do
  use ExUnit.Case, async: false

  alias Daftka.Metadata.Store
  alias Daftka.Types

  setup do
    assert Process.whereis(Store)
    Store.clear()
    :ok
  end

  test "create_topic succeeds and duplicate is rejected" do
    {:ok, topic} = Types.new_topic("orders")
    assert :ok == Store.create_topic(topic)
    assert {:ok, %{partitions: parts}} = Store.get_topic(topic)
    assert Map.keys(parts) == [0]
    assert {:error, :topic_exists} == Store.create_topic(topic)
  end

  test "invalid inputs return errors" do
    assert {:error, :invalid_topic} == Store.create_topic("orders")
  end

  test "get_topic for missing returns not_found" do
    {:ok, topic} = Types.new_topic("missing")
    assert {:error, :not_found} == Store.get_topic(topic)
  end

  test "delete_topic works and idempotent" do
    {:ok, topic} = Types.new_topic("ephemeral")
    assert :ok == Store.create_topic(topic)
    assert :ok == Store.delete_topic(topic)
    assert {:error, :not_found} == Store.delete_topic(topic)
    assert {:error, :not_found} == Store.get_topic(topic)
  end

  test "list_topics returns typed topics" do
    {:ok, t1} = Types.new_topic("a")
    {:ok, t2} = Types.new_topic("b")
    :ok = Store.create_topic(t1)
    :ok = Store.create_topic(t2)

    list = Store.list_topics()
    names = list |> Enum.map(fn {topic, _} -> Types.topic_value(topic) end) |> MapSet.new()
    assert names == MapSet.new(["a", "b"])

    assert Enum.all?(list, fn {topic, meta} ->
             Types.topic?(topic) and match?(%{partitions: _}, meta)
           end)
  end

  test "set and get partition owners" do
    {:ok, topic} = Types.new_topic("with_owners")
    {:ok, p0} = Types.new_partition(0)
    {:ok, p1} = Types.new_partition(1)
    :ok = Store.create_topic(topic, 2)

    owner0 = self()
    assert :ok == Store.set_partition_owner(topic, p0, owner0)
    assert {:ok, ^owner0} = Store.get_partition_owner(topic, p0)

    # Another pid for p1
    owner1 =
      spawn(fn ->
        receive do
          _ -> :ok
        end
      end)

    try do
      assert :ok == Store.set_partition_owner(topic, p1, owner1)
      assert {:ok, ^owner1} = Store.get_partition_owner(topic, p1)
    after
      Process.exit(owner1, :kill)
    end

    # Invalids
    assert {:error, :invalid_topic} = Store.set_partition_owner("bad", p0, owner0)
    assert {:error, :invalid_partition} = Store.set_partition_owner(topic, 0, owner0)
    assert {:error, :invalid_pid} = Store.set_partition_owner(topic, p0, :not_a_pid)
    {:ok, topic2} = Types.new_topic("nope")
    assert {:error, :not_found} = Store.get_partition_owner(topic2, p0)
    :ok = Store.create_topic(topic2)
  end
end
