defmodule Daftka.Naming do
  @moduledoc """
  Helpers for building `:via` tuples with gproc.

  Uses global names when the node is part of a distributed system, otherwise
  falls back to local names to keep unit tests working in non-distributed mode.
  """

  @type name :: term()

  @doc """
  Return a `:via` tuple for the given name using gproc.

  - If node is distributed (`Node.alive?/0`), use gproc global names.
  - Otherwise, use gproc local names (scope `:l`) so APIs behave consistently.
  """
  @spec via(name()) :: GenServer.name()
  def via(name) do
    {:via, :gproc, {:n, scope(), name}}
  end

  @doc """
  Resolve current gproc scope.
  """
  @spec scope() :: :g | :l
  def scope, do: if(Node.alive?(), do: :g, else: :l)
end
