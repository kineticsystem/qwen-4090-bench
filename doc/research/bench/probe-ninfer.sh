#!/bin/bash
# Binary-search the largest --max-context (= --kv-capacity) that NInfer's memory
# planner accepts, for each configuration, in steps of 4096 tokens.
# Usage: bench/probe-ninfer.sh "<label>|<args>" ...
cd "$(dirname "$0")/.."
starts() {  # $1 = context, rest = args; true when the server reaches "listening"
  local n=$1; shift
  docker rm -f qr-probe >/dev/null 2>&1
  docker run -d --name qr-probe --gpus all --network host -e NVIDIA_DISABLE_REQUIRE=1 \
    -v "$PWD:/work" qr-ninfer:sm89 /work/bench/serve-ninfer.sh --port 8099 \
    --max-context $n --kv-capacity $n "$@" >/dev/null
  local i; for i in $(seq 1 90); do
    docker logs qr-probe 2>&1 | grep -q "listening on" && { docker rm -f qr-probe >/dev/null; return 0; }
    [ "$(docker inspect -f '{{.State.Running}}' qr-probe)" = true ] || break
    sleep 1
  done
  docker rm -f qr-probe >/dev/null; return 1
}
for cfg in "$@"; do
  label=${cfg%%|*}; args=${cfg#*|}
  lo=0; hi=$((1048576 / 4096))  # in units of 4096 tokens
  while [ $((hi - lo)) -gt 1 ]; do
    mid=$(((lo + hi) / 2))
    if starts $((mid * 4096)) $args; then lo=$mid; else hi=$mid; fi
  done
  echo "$label max_context=$((lo * 4096))"
done
