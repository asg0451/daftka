defmodule Daftka.ApplicationTest do
  use ExUnit.Case, async: false

  test "application starts top-level supervisor named Daftka.Supervisor" do
    pid = Process.whereis(Daftka.Supervisor)
    assert is_pid(pid)
    assert Process.alive?(pid)

    assert Supervisor.which_children(Daftka.Supervisor) == []
  end
end
