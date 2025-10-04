# TODOs
Execute items from this list. When finished, make sure you check it off. See PLAN.md for details.


## Repo setup
- [x] Initialize application supervision entrypoint `Daftka.Application` with empty supervisors (no behavior yet)
- [x] Add base types module with opaque types for topic, partition, offset; add `@spec` to public APIs
- [x] Tooling: add Credo, Dialyxir, ExDoc; set up basic configs and Mix aliases
- [x] Set up github actions ci

## MVP - no replication, single node
*From here on out, we should always strive to have a vertical slice of the app working, and a test suite that tests it adequately.*

- [x] add skeletons for everything listed in the Component Overview in PLAN.md. they should all be registered normally and be genservers or actors as appropriate, but with no functionality.
- [x] implement the Metadata Store as a simple in memory kv agent
- [X] implement the Storage module as a simple in memory log-storage agent (list of Messages (offset, key, value, headers; make a struct for this in Types))
- [ ] implement the Partition Group as a genserver wrapper around its storage actor. it wont actually be a group, but will really be more similar to a Partition Replica Server.
- [x] implement the Rebalancer as a simple metadata store poller that spawns partition groups
- [ ] implement the Metadata api server
- [ ] implement the request router
- [ ] implement the http api gateway
- [ ] add integration tests to test the whole thing end to end

## Move to multi node
- [ ] adopt `libcluster` with the epmd strategy to go multi-node. make sure the test framework can support this. use a simple topology and ensure every process can route to every other process, to start. for example every process on every node must be able to talk to the metadata store.
- [ ] separate the control plane node set from the data plane one -- they may overlap in dev but must be separable.
- [ ] assign control plane processes to the control plane node set and vice versa. this may involve supervisor tree changes
- [ ] rewrite the Metadata Store to be a raft group using https://github.com/rabbitmq/ra. factor it to make it easy to make other raft groups in the future (for the partition groups). see https://github.com/rabbitmq/ra/blob/main/docs/internals/STATE_MACHINE_TUTORIAL.md and https://github.com/rabbitmq/ra-examples/blob/master/elixir_rakv/lib/ra_kv/machine.ex as well as examples.
- [ ] rewrite the storage module to use rocksdb to store data
- [ ] rewrite the partition group to be a raft group of partition replica servers, using `ra` like in the metadata store
