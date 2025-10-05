#!/usr/bin/env bash
set -euo pipefail

# Multi-node integration test for Daftka using epmd/libcluster.
# Spawns two short-lived nodes, creates a topic on node1, produces via node2,
# and fetches back the data to assert cross-node routing works.

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
export MIX_ENV=test

COOKIE="daftka_cookie"
PORT1=4101
PORT2=4102
DIST_MIN=9200
DIST_MAX=9250

export DAFTKA_COOKIE="$COOKIE"
export DAFTKA_DIST_MIN=$DIST_MIN
export DAFTKA_DIST_MAX=$DIST_MAX

cleanup() {
  set +e
  if [[ -n "${NODE1_PID:-}" ]]; then kill $NODE1_PID 2>/dev/null || true; fi
  if [[ -n "${NODE2_PID:-}" ]]; then kill $NODE2_PID 2>/dev/null || true; fi
  (sleep 0.5; pkill -f "-name daftka1@" 2>/dev/null || true) &
  (sleep 0.5; pkill -f "-name daftka2@" 2>/dev/null || true) &
}
trap cleanup EXIT

cd "$ROOT_DIR"

# Ensure deps and compile once
export PATH=$HOME/.elixir-install/installs/otp/27.3.4/bin:$PATH
export PATH=$HOME/.elixir-install/installs/elixir/1.18.4-otp-27/bin:$PATH

if ! command -v mix >/dev/null 2>&1; then
  echo "Elixir not installed; please run the background agent setup to install elixir/otp" >&2
  exit 1
fi

mix deps.get > /dev/null
mix compile > /dev/null

# Start node1 (control+data plane)
DAFTKA_NODE_NAME="daftka1@127.0.0.1" DAFTKA_ENABLE_CP=1 DAFTKA_ENABLE_DP=1 DAFTKA_GATEWAY_PORT=$PORT1 DAFTKA_CLUSTER_HOSTS="daftka1@127.0.0.1,daftka2@127.0.0.1" \
  elixir --erl "-setcookie $COOKIE" --name daftka1@127.0.0.1 -S mix run --no-halt &
NODE1_PID=$!

# Start node2 (data plane only)
DAFTKA_NODE_NAME="daftka2@127.0.0.1" DAFTKA_ENABLE_CP=0 DAFTKA_ENABLE_DP=1 DAFTKA_GATEWAY_PORT=$PORT2 DAFTKA_CLUSTER_HOSTS="daftka1@127.0.0.1,daftka2@127.0.0.1" \
  elixir --erl "-setcookie $COOKIE" --name daftka2@127.0.0.1 -S mix run --no-halt &
NODE2_PID=$!

# Wait for gateways to become healthy
wait_http_ok() {
  local port=$1
  for i in {1..60}; do
    if curl -fsS "http://localhost:${port}/healthz" > /dev/null; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

wait_http_ok $PORT1
wait_http_ok $PORT2

# Create a topic via node1
curl -fsS -X POST -H 'content-type: application/json' \
  -d '{"name":"cluster_topic","partitions":1}' \
  "http://localhost:${PORT1}/topics" > /dev/null

# Wait a moment for rebalancer to start the partition
sleep 0.5

# Produce via node2
RESP=$(curl -fsS -X POST -H 'content-type: application/json' \
  -d '{"key":"k","value":"v","headers":{}}' \
  "http://localhost:${PORT2}/topics/cluster_topic/partitions/0/produce")
OFFSET=$(echo "$RESP" | jq -r '.offset')
if [[ "$OFFSET" != "0" ]]; then
  echo "Expected offset 0, got: $OFFSET" >&2
  exit 1
fi

# Fetch via node1
RESP2=$(curl -fsS "http://localhost:${PORT1}/topics/cluster_topic/partitions/0/fetch?from_offset=0&max_count=10")
KEY=$(echo "$RESP2" | jq -r '.messages[0].key')
VAL=$(echo "$RESP2" | jq -r '.messages[0].value')
if [[ "$KEY" != "k" || "$VAL" != "v" ]]; then
  echo "Unexpected message payload key=$KEY val=$VAL" >&2
  exit 1
fi

echo "Multi-node integration passed."
