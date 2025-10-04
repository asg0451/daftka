defmodule DaftkaMessageTest do
  use ExUnit.Case, async: true

  alias Daftka.Types

  test "new_message validates fields" do
    {:ok, off} = Types.new_offset(0)

    assert {:ok, msg} = Types.new_message(off, "k", "v", %{"a" => "b"})
    assert Types.message_key(msg) == "k"
    assert Types.message_value(msg) == "v"
    assert Types.message_headers(msg) == %{"a" => "b"}
    assert Types.offset_value(Types.message_offset(msg)) == 0

    assert {:error, :invalid_message_key} = Types.new_message(off, 123, "v", %{})
    assert {:error, :invalid_message_value} = Types.new_message(off, "k", 456, %{})
    assert {:error, :invalid_message_headers} = Types.new_message(off, "k", "v", %{a: :b})
    assert {:error, :invalid_message_offset} = Types.new_message(:bad, "k", "v", %{})
  end
end
