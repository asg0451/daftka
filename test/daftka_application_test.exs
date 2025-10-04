defmodule Daftka.ApplicationTest do
  use ExUnit.Case, async: false

  test "application starts top-level supervisor named Daftka.Supervisor" do
    pid = Process.whereis(Daftka.Supervisor)
    assert is_pid(pid)
    assert Process.alive?(pid)

    children = Supervisor.which_children(Daftka.Supervisor)

    assert Enum.any?(children, fn
             {_, child_pid, :supervisor, [Daftka.ControlPlane]} when is_pid(child_pid) -> true
             _ -> false
           end)
  end
end
