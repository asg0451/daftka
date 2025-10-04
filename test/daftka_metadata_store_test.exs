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
    assert :ok == Store.create_topic(topic, 3)
    assert {:ok, %{partition_count: 3}} == Store.get_topic(topic)
    assert {:error, :topic_exists} == Store.create_topic(topic, 3)
  end

  test "invalid inputs return errors" do
    assert {:error, :invalid_topic} == Store.create_topic("orders", 3)
    {:ok, topic} = Types.new_topic("bad")
    assert {:error, :invalid_partitions} == Store.create_topic(topic, 0)
    assert {:error, :invalid_partitions} == Store.create_topic(topic, -1)
  end

  test "get_topic for missing returns not_found" do
    {:ok, topic} = Types.new_topic("missing")
    assert {:error, :not_found} == Store.get_topic(topic)
  end

  test "delete_topic works and idempotent" do
    {:ok, topic} = Types.new_topic("ephemeral")
    assert :ok == Store.create_topic(topic, 1)
    assert :ok == Store.delete_topic(topic)
    assert {:error, :not_found} == Store.delete_topic(topic)
    assert {:error, :not_found} == Store.get_topic(topic)
  end

  test "list_topics returns typed topics" do
    {:ok, t1} = Types.new_topic("a")
    {:ok, t2} = Types.new_topic("b")
    :ok = Store.create_topic(t1, 1)
    :ok = Store.create_topic(t2, 2)

    list = Store.list_topics()
    names = list |> Enum.map(fn {topic, _} -> Types.topic_value(topic) end) |> MapSet.new()
    assert names == MapSet.new(["a", "b"])

    assert Enum.all?(list, fn {topic, meta} -> Types.topic?(topic) and is_map(meta) end)
  end
end
