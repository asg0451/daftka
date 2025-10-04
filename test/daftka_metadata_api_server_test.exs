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
  end

  test "get_topic and delete_topic work via names" do
    assert {:error, :invalid_topic} = MetadataAPI.get_topic(1)
    assert {:error, :invalid_topic} = MetadataAPI.delete_topic(:foo)

    assert {:error, :not_found} = MetadataAPI.get_topic("missing")

    :ok = MetadataAPI.create_topic("t1")
    assert {:ok, %{owners: %{}}} = MetadataAPI.get_topic("t1")

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
end
