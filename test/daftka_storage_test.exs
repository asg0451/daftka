defmodule DaftkaStorageTest do
  use ExUnit.Case, async: true

  alias Daftka.PartitionReplica.Storage

  setup do
    {:ok, pid} = Storage.start_link()
    %{storage: pid}
  end

  test "put/get roundtrip", %{storage: storage} do
    assert :error == Storage.get(storage, :missing)

    :ok = Storage.put(storage, :foo, 123)
    assert {:ok, 123} == Storage.get(storage, :foo)
  end

  test "delete removes key", %{storage: storage} do
    :ok = Storage.put(storage, :foo, 1)
    assert {:ok, 1} == Storage.get(storage, :foo)

    :ok = Storage.delete(storage, :foo)
    assert :error == Storage.get(storage, :foo)
  end

  test "clear resets state", %{storage: storage} do
    :ok = Storage.put(storage, :a, 1)
    :ok = Storage.put(storage, :b, 2)
    assert Storage.size(storage) == 2

    :ok = Storage.clear(storage)
    assert Storage.size(storage) == 0
    assert Storage.keys(storage) == []
    assert Storage.values(storage) == []
  end

  test "keys and values reflect contents", %{storage: storage} do
    :ok = Storage.put(storage, :a, 1)
    :ok = Storage.put(storage, :b, 2)

    keys = Storage.keys(storage) |> Enum.sort()
    vals = Storage.values(storage) |> Enum.sort()

    assert keys == [:a, :b]
    assert vals == [1, 2]
  end
end
