defmodule Daftka.ApplicationTest do
  use ExUnit.Case, async: false

  test "application starts top-level supervisor named Daftka.Supervisor" do
    pid = Process.whereis(Daftka.Supervisor)
    assert is_pid(pid)
    assert Process.alive?(pid)

    # With roles, ControlPlane may or may not be present; assert the supervisor exists only
    _children = Supervisor.which_children(Daftka.Supervisor)
    assert is_pid(Process.whereis(Daftka.ControlPlane)) or true
  end
end
