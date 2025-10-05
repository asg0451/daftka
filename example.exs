#! /usr/bin/env mix run

# :observer.start()
:ok = Daftka.MetadataAPI.Server.create_topic("hi", 4)
:ok = Daftka.MetadataAPI.Server.wait_for_online("hi", 0, 1000)
{:ok, t} = Daftka.Types.new_topic("hi")
{:ok, p} = Daftka.Types.new_partition(0)
{:ok, prs} = Daftka.Metadata.Store.get_partition_owner(t, p)

_ =
  Enum.map(1..10, fn x ->
    {:ok, _offset} = Daftka.PartitionReplica.Server.append(prs, "k-#{x}", "v-#{x}")
  end)

{:ok, o} = Daftka.Types.new_offset(0)
{:ok, msgs} = Daftka.PartitionReplica.Server.fetch_from(prs, o, 5)

IO.inspect(msgs, pretty: true)
