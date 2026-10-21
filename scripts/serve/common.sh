# shellcheck shell=bash
# The variables are used by the scripts that source this file.
# shellcheck disable=SC2034

# Shared by the server scripts of scripts/serve. Each runs one engine in the foreground,
# as llama-swap needs it: llama-swap starts it with --port, waits for /health, and stops
# it with SIGTERM.

WS=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
E=$WS/engines B=$WS/build M=${MODELS:-/models}
PORT=8090

# The recommended sampling of Qwen3.8-27B.
TEMP=0.6 TOP_P=0.95 TOP_K=20 MIN_P=0

# Fail early, with the reason, when a file the engine needs is missing.
need() {
  local f
  for f in "$@"; do
    [ -e "$f" ] || { echo "missing $f: run ./docker/dock.sh build and ./docker/dock.sh models" >&2; exit 1; }
  done
}

# Wait until no socket uses the port, closing connections included: NInfer cannot bind a
# port whose connections are still in TIME_WAIT, as after a quick restart of the same model.
wait_port_free() {
  for _ in $(seq 1 90); do
    ss -tan | grep -q ":$PORT " || return 0
    sleep 1
  done
}
