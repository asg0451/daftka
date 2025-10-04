defmodule DaftkaPartitionStorageTest do
  use ExUnit.Case, async: false

  alias Daftka.PartitionReplica.Storage
  alias Daftka.Types

  setup do
    start_supervised!({Storage, name: Storage})
    :ok
  end

  test "next_offset starts at 0 and advances on append" do
    assert %Types.Offset{} = Storage.next_offset()
    assert Types.offset_value(Storage.next_offset()) == 0

    assert {:ok, o1} = Storage.append(Storage, "k1", "v1", %{"h" => "1"})
    assert Types.offset_value(o1) == 0
    assert Types.offset_value(Storage.next_offset()) == 1

    assert {:ok, o2} = Storage.append(Storage, "k2", "v2", %{})
    assert Types.offset_value(o2) == 1
    assert Types.offset_value(Storage.next_offset()) == 2
  end

  test "fetch_from returns messages from offset with max count" do
    {:ok, _} = Storage.append(Storage, "k1", "v1", %{"x" => "a"})
    {:ok, _} = Storage.append(Storage, "k2", "v2", %{"y" => "b"})
    {:ok, _} = Storage.append(Storage, "k3", "v3", %{"z" => "c"})

    assert {:ok, msgs} = Storage.fetch_from(Storage, Types.new_offset(1) |> elem(1), 2)
    assert length(msgs) == 2

    [m1, m2] = msgs
    assert Types.message_key(m1) == "k2"
    assert Types.message_value(m1) == "v2"
    assert Types.offset_value(Types.message_offset(m1)) == 1
    assert Types.message_headers(m1) == %{"y" => "b"}

    assert Types.message_key(m2) == "k3"
    assert Types.offset_value(Types.message_offset(m2)) == 2
  end

  test "append with invalid args returns error" do
    assert {:error, :invalid_append_args} = Storage.append(Storage, :not_binary, "v", %{})
    assert {:error, :invalid_append_args} = Storage.append(Storage, "k", 123, %{})
    assert {:error, :invalid_append_args} = Storage.append(Storage, "k", "v", :not_map)
  end

  test "fetch_from invalid args returns error" do
    assert {:error, :invalid_fetch_args} = Storage.fetch_from(Storage, :bad, 10)

    assert {:error, :invalid_fetch_args} =
             Storage.fetch_from(Storage, Types.new_offset(0) |> elem(1), 0)
  end
end
