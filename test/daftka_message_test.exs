defmodule DaftkaMessageTest do
  use ExUnit.Case, async: true

  alias Daftka.Types

  test "new_message validates fields" do
    {:ok, off} = Types.new_offset(0)

    assert {:ok, msg} = Types.new_message(off, "k", "v", %{"a" => "b"})
    assert msg.key == "k"
    assert msg.value == "v"
    assert msg.headers == %{"a" => "b"}
    assert Types.offset_value(msg.offset) == 0

    assert {:error, :invalid_message_key} = Types.new_message(off, 123, "v", %{})
    assert {:error, :invalid_message_value} = Types.new_message(off, "k", 456, %{})
    assert {:error, :invalid_message_headers} = Types.new_message(off, "k", "v", %{a: :b})
    assert {:error, :invalid_message_offset} = Types.new_message(:bad, "k", "v", %{})
  end
end
