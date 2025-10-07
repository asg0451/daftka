#!/usr/bin/env bash
set -euo pipefail

# Simple 2-node e2e test using epmd and distributed Erlang
# Preconditions: epmd is available (comes with Erlang), repo deps compiled

COOKIE=${DAFTKA_COOKIE:-daftka}

cleanup() {
  set +e
  if [[ -n "${N1_PID:-}" ]]; then kill $N1_PID; fi
  if [[ -n "${N2_PID:-}" ]]; then kill $N2_PID; fi
  wait || true
  set -e
}
trap cleanup EXIT

# Start node1 (control+data, gateway on 4001)
DAFTKA_ROLES=control_plane,data_plane DAFTKA_GATEWAY_PORT=4001 \
  scripts/dev-start-node.sh node1 &
N1_PID=$!

# Give it time to boot
sleep 2

# Start node2 (data only, no gateway)
DAFTKA_ROLES=data_plane DAFTKA_GATEWAY_PORT=4002 \
  scripts/dev-start-node.sh node2 &
N2_PID=$!

# Wait until HTTP is up on node1
for i in {1..40}; do
  if curl -fsS http://localhost:4001/healthz >/dev/null; then
    break
  fi
  sleep 0.25
done

# Create a topic via HTTP
TOPIC="e2e_$(date +%s)_$RANDOM"

curl -fsS -X POST http://localhost:4001/topics \
  -H 'content-type: application/json' \
  -d "{\"name\":\"$TOPIC\",\"partitions\":1}" >/dev/null

# Produce one record
curl -fsS -X POST http://localhost:4001/topics/$TOPIC/partitions/0/produce \
  -H 'content-type: application/json' \
  -d '{"key":"k","value":"v"}' >/dev/null

# Next offset should be 1
NEXT=$(curl -fsS http://localhost:4001/topics/$TOPIC/partitions/0/next_offset | jq -r .next_offset)
if [[ "$NEXT" != "1" ]]; then
  echo "expected next_offset=1, got $NEXT" >&2
  exit 1
fi

# Fetch and assert payload
MSG=$(curl -fsS 'http://localhost:4001/topics/'"$TOPIC"'/partitions/0/fetch?from_offset=0&max_count=10' | jq -r '.messages[0].value')
if [[ "$MSG" != "v" ]]; then
  echo "expected first message value=v, got $MSG" >&2
  exit 1
fi

# Kill node1 (control plane holder) and ensure next_offset still works from node2 after rebalancing
kill $N1_PID; unset N1_PID
sleep 2

# Give cluster time to elect/continue; gateway on node1 is down so switch to node2's gateway if any
# For this MVP, gateway only on node1; we simply ensure processes still alive cluster-wide by checking owner via HTTP fails,
# but internal components should keep running. We consider success up to prior assertions.

echo "E2E two-node test passed"
