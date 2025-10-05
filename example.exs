#! /usr/bin/env mix run

# :observer.start()
:ok = Daftka.MetadataAPI.Server.create_topic("hi", 4)
:ok = Daftka.MetadataAPI.Server.wait_for_online("hi", 0, 1000)

{:ok, t} = Daftka.Types.new_topic("hi")
{:ok, p} = Daftka.Types.new_partition(0)

_ =
  Enum.map(1..10, fn x ->
    {:ok, _offset} = Daftka.Router.produce(t, p, "k-#{x}", "v-#{x}")
  end)

{:ok, o} = Daftka.Types.new_offset(0)
{:ok, msgs} = Daftka.Router.fetch_from(t, p, o, 5)

IO.inspect(msgs, pretty: true)
