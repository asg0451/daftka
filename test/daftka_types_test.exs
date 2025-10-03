defmodule Daftka.TypesTest do
  use ExUnit.Case, async: true

  alias Daftka.Types

  describe "topic" do
    test "new_topic trims and validates" do
      assert {:ok, t} = Types.new_topic("  foo  ")
      assert Types.topic_value(t) == "foo"
      assert Types.topic?(t)

      assert {:error, :invalid_topic} = Types.new_topic(123)
      assert {:error, :invalid_topic} = Types.new_topic("")
      assert {:error, :invalid_topic} = Types.new_topic("   ")
    end
  end

  describe "partition" do
    test "new_partition validates non-neg integer" do
      assert {:ok, p} = Types.new_partition(0)
      assert Types.partition_value(p) == 0
      assert Types.partition?(p)

      assert {:ok, p2} = Types.new_partition(10)
      assert Types.partition_value(p2) == 10

      assert {:error, :invalid_partition} = Types.new_partition(-1)
      assert {:error, :invalid_partition} = Types.new_partition("0")
    end
  end

  describe "offset" do
    test "new_offset validates non-neg integer" do
      assert {:ok, o} = Types.new_offset(0)
      assert Types.offset_value(o) == 0
      assert Types.offset?(o)

      assert {:ok, o2} = Types.new_offset(42)
      assert Types.offset_value(o2) == 42

      assert {:error, :invalid_offset} = Types.new_offset(-1)
      assert {:error, :invalid_offset} = Types.new_offset("1")
    end
  end
end
