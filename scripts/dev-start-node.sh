#!/usr/bin/env bash
set -euo pipefail

NAME=${1:-node1}
COOKIE=${DAFTKA_COOKIE:-daftka}
ROLES=${DAFTKA_ROLES:-control_plane,data_plane}
PORT=${DAFTKA_GATEWAY_PORT:-4001}

export DAFTKA_COOKIE="$COOKIE"
export DAFTKA_ROLES="$ROLES"
export DAFTKA_GATEWAY_PORT="$PORT"

# Start an Erlang distribution name with epmd
exec elixir --name ${NAME}@127.0.0.1 --cookie $COOKIE -S mix run --no-halt
