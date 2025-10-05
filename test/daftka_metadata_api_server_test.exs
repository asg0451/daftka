defmodule DaftkaMetadataAPIServerTest do
  use ExUnit.Case, async: false

  alias Daftka.Metadata.Store
  alias Daftka.MetadataAPI.Server, as: MetadataAPI

  setup do
    assert Process.whereis(MetadataAPI)
    Store.clear()
    :ok
  end

  test "create_topic validates and delegates to store" do
    assert {:error, :invalid_topic} = MetadataAPI.create_topic(123)

    assert :ok = MetadataAPI.create_topic("orders")
    assert {:error, :topic_exists} = MetadataAPI.create_topic("orders")

    # create with partitions
    assert {:error, :invalid_topic} = MetadataAPI.create_topic(123, 3)
    assert {:error, :invalid_partitions} = MetadataAPI.create_topic("pbad", 0)
    assert :ok = MetadataAPI.create_topic("p3", 3)
  end

  test "get_topic and delete_topic work via names" do
    assert {:error, :invalid_topic} = MetadataAPI.get_topic(1)
    assert {:error, :invalid_topic} = MetadataAPI.delete_topic(:foo)

    assert {:error, :not_found} = MetadataAPI.get_topic("missing")

    :ok = MetadataAPI.create_topic("t1", 2)
    assert {:ok, %{partitions: parts}} = MetadataAPI.get_topic("t1")
    assert Map.keys(parts) |> Enum.sort() == [0, 1]

    assert :ok = MetadataAPI.delete_topic("t1")
    assert {:error, :not_found} = MetadataAPI.get_topic("t1")
  end

  test "list_topics returns typed topics" do
    :ok = MetadataAPI.create_topic("a")
    :ok = MetadataAPI.create_topic("b")

    list = MetadataAPI.list_topics()
    assert is_list(list)

    names = list |> Enum.map(fn {topic, _} -> Daftka.Types.topic_value(topic) end) |> MapSet.new()
    assert names == MapSet.new(["a", "b"])
  end

  test "debug_dump returns full state with topics" do
    :ok = MetadataAPI.create_topic("orders", 2)
    :ok = MetadataAPI.create_topic("payments", 1)

    state = MetadataAPI.debug_dump()
    assert %{topics: topics} = state
    assert is_map(topics)
    assert Map.has_key?(topics, "orders")
    assert Map.has_key?(topics, "payments")

    assert %{partitions: parts_orders} = Map.fetch!(topics, "orders")
    assert parts_orders |> Map.keys() |> Enum.sort() == [0, 1]
  end
end
