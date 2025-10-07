defmodule Daftka.Naming do
  @moduledoc """
  Centralized helpers for gproc-based global names.

  All process registrations and lookups should go through this module.
  """

  @type key :: {:n, :g, term()}
  @type via :: {:via, :gproc, key()}

  @spec key_global(term()) :: key()
  def key_global(term), do: {:n, :g, {:daftka, term}}

  @spec via_global(term()) :: via()
  def via_global(term), do: {:via, :gproc, key_global(term)}

  # Partition-scoped names
  @spec partition_supervisor_via(String.t(), non_neg_integer()) :: via()
  def partition_supervisor_via(topic, partition),
    do: via_global({:partition_supervisor, topic, partition})

  @spec partition_server_via(String.t(), non_neg_integer()) :: via()
  def partition_server_via(topic, partition),
    do: via_global({:partition_server, topic, partition})

  @spec partition_storage_via(String.t(), non_neg_integer()) :: via()
  def partition_storage_via(topic, partition),
    do: via_global({:partition_storage, topic, partition})
end
