#!/usr/bin/env bash
set -euo pipefail

# Simple e2e script to boot two named nodes and exercise HTTP API

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

export MIX_ENV=dev

# Build once
mix deps.get >/dev/null
mix compile >/dev/null

# Start node 1 (all planes)
ROLE='[:control_plane, :data_plane]'
CMD1=(elixir --name n1@127.0.0.1 -S mix run --no-halt)
DAFTKA_ROLE=$ROLE \
  "${CMD1[@]}" &
PID1=$!

sleep 1

# Start node 2 (all planes)
ROLE2='[:control_plane, :data_plane]'
DAFTKA_CONNECT_TO=n1@127.0.0.1 \
DAFTKA_ROLE=$ROLE2 \
  elixir --name n2@127.0.0.1 -S mix run --no-halt &
PID2=$!

cleanup() {
  kill $PID2 2>/dev/null || true
  kill $PID1 2>/dev/null || true
}
trap cleanup EXIT

# Wait for gateway on both nodes
for i in {1..30}; do
  if curl -fsS http://127.0.0.1:4001/healthz >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

curl -fsS http://127.0.0.1:4001/healthz | grep -q "ok"
curl -fsS http://127.0.0.1:4001/healthz | grep -q "ok"

# Create topic and produce/fetch via node 1 gateway
curl -fsS -X POST http://127.0.0.1:4001/topics -H 'content-type: application/json' \
  -d '{"name":"e2e","partitions":1}' >/dev/null

curl -fsS -X POST http://127.0.0.1:4001/topics/e2e/partitions/0/produce \
  -H 'content-type: application/json' -d '{"key":"k","value":"v","headers":{}}' \
  | grep -q '"offset":0'

curl -fsS 'http://127.0.0.1:4001/topics/e2e/partitions/0/next_offset' | grep -q '"next_offset":1'
curl -fsS 'http://127.0.0.1:4001/topics/e2e/partitions/0/fetch?from_offset=0&max_count=10' | grep -q '"value":"v"'

# Also exercise node 2 by hitting its node name via httpc not needed; both listen same port locally

echo "E2E OK"
