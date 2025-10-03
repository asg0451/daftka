## Vision

Build an Elixir-first, Kafka-inspired queue-log system that is multi-tenant (topics) and sharded (partitions), offering both a native Elixir interface and a JSON HTTP API gateway for non-Elixir clients. The system emphasizes OTP best practices and strong typing with Elixir 1.18.

## Scope

- **Tenancy and Sharding**: Multiple topics (tenants) and partitions per topic.
- **Elixir Interface**: Idiomatic functions for producing, consuming, acknowledging, and inspecting stream position.
- **API Gateway**: JSON-over-HTTP endpoints for produce/consume/ack and basic introspection, suitable for polyglot clients.
- **Durability & Ordering**: Append-only log semantics with monotonic offsets; ordering guaranteed within a partition.
- **Observability**: Metrics, logs, and trace hooks for core operations.

## Guiding Principles

- **Deterministic Core**: Separate pure domain logic from side effects; make core behavior easy to test with property-based testing.
- **Crash-Only Design**: Embrace supervision; processes fail fast and are restarted predictably.
- **Explicit Semantics**: Delivery guarantees, ordering, and visibility rules are documented and asserted in tests.
- **Type-Rich APIs**: Prefer explicit types, opaque types, and `@spec` for public functions; keep Dialyzer clean.
- **Backpressure and Flow Control**: Provide mechanisms to avoid unbounded memory growth under load.
- **Compatibility and Evolvability**: Avoid lock-in to Kafka’s wire protocol; design a stable, versioned JSON API.

## Terminology (Glossary)

- **Topic**: A named, multi-tenant stream namespace. Isolation is enforced per topic.
- **Partition**: An ordered, append-only substream within a topic. Ordering is guaranteed per partition.
- **Offset**: A monotonic, partition-local position identifying a log entry.
- **Producer**: A client that appends records to a topic/partition.
- **Consumer**: A client that reads records from a topic/partition.
- **Record**: The minimal unit of data appended to a partition (key, value, headers, timestamp, metadata).

## Constraints

- **Language/Runtime**: Elixir 1.18 on BEAM; OTP behaviors for processes and supervision.
- **Typing**: Liberal use of types and `@spec`; Dialyzer required in CI.
- **Transport**: JSON HTTP for the gateway. No Kafka protocol compatibility required.
- **Dependencies**: Favor standard library and battle-tested Elixir/Erlang libraries; avoid native NIFs initially.
- **Resource Isolation**: Per-topic limits and quotas considered as part of multi-tenancy.

## Non-Goals (Initial)

- Kafka protocol compatibility, cross-datacenter replication, and tiered storage.
- Exactly-once semantics across partitions; initial target is at-least-once within a partition.
- Transactions spanning multiple topics/partitions.

## Intended Behaviors (High-Level)

- **Ordering**: Records are delivered in append order within a partition.
- **Offsets**: Offsets are strictly increasing per partition; gaps only occur due to compaction or administrative actions.
- **Delivery Semantics**: At-least-once delivery; idempotent production encouraged via keys/headers.
- **Acknowledgements**: Only `acks=all` is supported; writes are acknowledged after quorum commit.
- **Visibility**: A record becomes visible to consumers after it is durably appended to the partition’s log.

## Observability & Operability (Baseline)

- **Metrics**: Production/consumption rates, consumer lag per partition, append latency, storage usage.
- **Logs**: Structured logs with correlation IDs; avoid sensitive payload logging by default.
- **Health**: Lightweight readiness/liveness checks for the gateway and core services.

## Testing Approach

- **Unit Tests**: Exercise domain behaviors and error conditions.
- **Property-Based Tests**: Validate ordering, offset monotonicity, and idempotence invariants.
- **Integration Tests**: Validate Elixir client and JSON HTTP endpoints end-to-end.

## Performance Targets (Initial, Aspirational)

- Single-node throughput and tail-latency targets will be validated by micro-benchmarks; hard numbers to be set after the first working prototype. Avoid regressions by documenting baseline results.

## Security & Multi-Tenancy Baseline

- Enforce tenant isolation across topics; avoid cross-topic data access.
- Validate and sanitize all HTTP inputs
- Provide reasonable defaults for retention and compaction policies.

## Architecture (High-Level)

- **Partition as Consensus Group**: Each partition is replicated via a Raft consensus group. A single leader accepts writes, commits after quorum persistence, and advances the high watermark.
- **Acknowledgements**: Producers receive success only after quorum commit (`acks=all` only). This aligns visibility with durability.
- **Ordering & Offsets**: Ordering is guaranteed within a partition by the consensus log index; offsets advance monotonically upon commit.
- **Snapshots & Compaction**: Periodic snapshots and log truncation bound recovery time and storage, independent of record retention policies.
- **Routing**: Clients and the gateway route requests to the current partition leader; retries on redirect are expected on leadership changes.

## Architecture & Supervision Organization

### Component Overview


- HTTP API Gateway
    - provide http json api layer on top of native erlang stuff. stateless.
- Request Router
    - take a request for a topic-partition, look up the raft group corresponding to that topic-partition and its leader in the Metadata store, and proxy the request to it
- Metadata store
    - replicated kv store using its own raft group
    - contains metadata about topics and partitions and leaders and nodes
        - knows who leaders and replicas (pid,node) are (they tell it on election)
        - desired replication factor
        - what nodes are in the cluster and what their assignments are
        - etc
- Partition Group (for organization; just a raft group comprised of Partition Replica Servers)
- Partition Replica Server
    - responsible for a given topic-partition replica
    - may be leader or follower in raft group
    - if leader, serves Add and Get requests to storage
- Storage
    - responsible for storing and retrieving data for a single topic-partition
    - uses rocksdb on a local disk
    - colocated & owned by its Partition Replica Server
- Rebalancer
    - singleton; uses Metadata store as source of truth
    - monitors what is where and decides if a reassignment of a partition replica to another erlang node is required
        - wants to distribute replicas for a given raft group across nodes to ensure survival goals
        - takes load into account as well after that
    - responsible for creating and destroying partition replica server groups
- Metadata API Server
    - Create/DeleteTopic: adds entry to Metadata store and triggers rebalancer to create and assign replicas
    - others?
- Admin API Server
    - Drain: trigger Rebalencer to "drain" nodes of replicas and reassigns them to other nodes
    - AddNode: add node to Metadata store's cluster info
    - Reassign: trigger Rebalancer to reassign replicas manually
    - drives those reassignments via some mechanism tbd
- TODO: some mechanism that controls node placement of control plance processes (Metadata store, rebalancer, admin api server)


### Top-level Supervision Tree

TODO. keep in mind it's a multi node system

Daftka.ControlPlane (Supervisor, one_for_one)
  ├─ Daftka.Cluster.Supervisor (Supervisor)
  │   └─ Node membership/cluster strategy (e.g., libcluster or static)
  ├─ Daftka.Metadata.Supervisor (Supervisor, rest_for_one)
  │   └─ Metadata Raft group
  │     └─ Metadata KV Server
  ├─ Daftka.Router.Supervisor (Supervisor)
  │   └─ Request Router
  ├─ Daftka.Gateway.Supervisor (Supervisor)
  │   └─ HTTP API Gateway (Plug/Cowboy)
  └─ Daftka.Partitions.Supervisor (DynamicSupervisor)
      └─ PartitionReplica.Supervisor (one_for_all, per replica)
          ├─ PartitionReplica.Raft
          ├─ PartitionReplica.Storage (RocksDB-backed)
          └─ PartitionReplica.Server
```

- The `DynamicSupervisor` manages lifecycle for all partition replicas on the local node.
- Each `PartitionReplica.Supervisor` is `one_for_all` so storage and server restart together to preserve invariants.
- The `Metadata.Supervisor` uses `rest_for_one` to restart dependent processes in-order if its core fails.

### Process Naming & Discovery
- Metadata store is the source of truth for what nodes are in the cluster and what replicas they provide.
- Use `libcluster` to support seamless multi node processes.

### Failure Handling & Restart Strategies
- Crash-Only Processes
    - Processes fail fast; supervisors own recovery. Avoid defensive code that masks faults.
- Supervisor Strategies
    - `PartitionReplica.Supervisor`: `one_for_all` (restart raft/server/storage together). Exponential backoff with caps; restart intensity tuned to avoid thrash.
    - `Partitions.Supervisor`: `DynamicSupervisor` with `max_restarts`/`max_seconds` tuned; repeated failures trigger circuit open for that replica with backpressure signals.
    - `Metadata.Supervisor`: `rest_for_one` to ensure dependent processes restart in-order after metadata recovery.
- Persistence Safety
    - Writes acknowledge only after quorum commit and fsync policy; snapshots and log compaction bound recovery time.

### Observability
- Telemetry Events (examples)
    - `[:daftka, :producer, :append, :start|:stop|:exception]`
    - `[:daftka, :consumer, :fetch, :start|:stop|:exception]`
    - `[:daftka, :partition, :election]`, `[:daftka, :raft, :commit]`, `[:daftka, :storage, :flush]`
- Metrics
    - Per-partition: append rate, fetch rate, commit latency, consumer lag, high-watermark, storage size, snapshot duration.
    - Node-level: CPU, memory, mailbox depths of hot processes, queue lengths, GC time.
    - Export via metrics reporter (e.g., Prometheus) with a `/metrics` endpoint.
- Logging
    - Structured logs with correlation/request IDs. No payload bodies by default; redact keys/headers if logged.
    - Gateway access logs with latency, status, and routing target.
- Health & Readiness
    - Liveness: process heartbeats and HTTP `/healthz`.
    - Readiness: gateway ready only when metadata is available and local partitions have recovered.

### Configuration Knobs (by application config)

Suggested keys (defaults are placeholders):
- Cluster & Placement
    - `daftka.cluster.strategy` (e.g., static|gossip), `daftka.cluster.seed_nodes` (list)
    - `daftka.replication_factor` (default: 3), `daftka.partitions_per_topic` (default: 3)
    - `daftka.rebalance.max_parallel_transfers` (default: 1)
- Raft & Log
    - `daftka.raft.election_timeout_ms` (jittered, default: 150..300)
    - `daftka.raft.heartbeat_interval_ms` (default: 50)
    - `daftka.snapshot.interval_ops` (default: 50_000)
    - `daftka.snapshot.max_log_size_bytes` (default: 134_217_728)
- Storage
    - `daftka.storage.path` (default: "data/daftka")
    - `daftka.storage.flush_interval_ms` (default: 5)
    - `daftka.retention.time_ms` / `daftka.retention.bytes`
- Gateway & Router
    - `daftka.gateway.port` (default: 4001)
    - `daftka.gateway.request_timeout_ms` (default: 5_000)
    - `daftka.router.retry_backoff_ms` (min..max)
- Backpressure & Limits
    - `daftka.producer.max_batch_records` (default: 1000)
    - `daftka.replica.max_inflight_bytes` and `max_inflight_requests`
- Observability
    - `daftka.metrics.port` (default: 9568)
    - `daftka.log.level` (default: info)
- Debug
    - `daftka.dev_single_node` (default: false)
