defmodule DaftkaTest do
  use ExUnit.Case
  doctest Daftka

  test "greets the world" do
    assert Daftka.hello() == :world
  end
end
