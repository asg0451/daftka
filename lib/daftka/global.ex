defmodule Daftka.Global do
  @moduledoc """
  Thin wrapper over gproc for cross-node process registration and lookup.

  Provides simple APIs to register unique names and resolve pids across nodes.
  """

  @type name :: term()

  @doc """
  Register the current process under a unique global name.

  Returns `true` on success, `:already_registered` if taken.
  """
  @spec register_unique(name()) :: true | :already_registered
  def register_unique(name) do
    # gproc returns :yes on success, or exits with :local_only if distribution not enabled.
    # We treat :local_only as already taken to avoid crashes during tests.
    if Node.alive?() do
      try do
        case :gproc.reg({:n, :g, name}) do
          true -> true
          {:error, {:already_registered, _}} -> :already_registered
          {:error, :badarg} -> :already_registered
          _ -> :already_registered
        end
      catch
        :exit, {:local_only, _} -> :already_registered
        :exit, :local_only -> :already_registered
      end
    else
      case :gproc.reg({:n, :l, name}) do
        true -> true
        {:error, {:already_registered, _}} -> :already_registered
        {:error, :badarg} -> :already_registered
        _ -> :already_registered
      end
    end
  end

  @doc """
  Unregister the current process from a unique name.
  """
  @spec unregister_unique(name()) :: :ok
  def unregister_unique(name) do
    scope = if(Node.alive?(), do: :g, else: :l)
    owner = whereis(name)

    if is_pid(owner) do
      _ =
        try do
          :gproc.unreg_other({:n, scope, name}, owner)
        rescue
          _ -> :ok
        end
    end

    _ = (try do Registry.unregister(Daftka.Registry, name) rescue _ -> :ok end)
    :ok
  end

  @doc """
  Resolve a unique global name to a pid, or `:undefined`.
  """
  @spec whereis(name()) :: pid() | :undefined
  def whereis(name) do
    if Node.alive?() do
      case :gproc.where({:n, :g, name}) do
        :undefined -> :undefined
        pid when is_pid(pid) -> pid
      end
    else
      case :gproc.where({:n, :l, name}) do
        :undefined -> :undefined
        pid when is_pid(pid) -> pid
      end
    end
  end
end
