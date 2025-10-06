defmodule DaftkaGlobalTest do
  use ExUnit.Case, async: false

  test "register, whereis, unregister unique name" do
    name = {:test_global, System.unique_integer([:positive])}

    pid =
      spawn(fn ->
        :ok =
          receive do
            :stop -> :ok
          end
      end)

    # Register the spawned process by proxy: gproc requires current proc; so link and send reg
    ref = make_ref()
    parent = self()

    task =
      Task.async(fn ->
        Process.flag(:trap_exit, true)
        :erlang.link(pid)
        true = Daftka.Global.register_unique(name)
        send(parent, {:registered, ref})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:registered, ^ref}, 1000
    assert is_pid(Daftka.Global.whereis(name))

    Daftka.Global.unregister_unique(name)
    # Allow a tick for unregister propagation in gproc/local
    Process.sleep(10)
    assert Daftka.Global.whereis(name) == :undefined

    send(pid, :stop)
    send(task.pid, :stop)
  end
end
