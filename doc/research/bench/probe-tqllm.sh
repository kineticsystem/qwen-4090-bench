#!/bin/bash
# Binary-search the largest --context that azllm (tqserve -fitl off) starts with.
# Usage: bench/probe-tqllm.sh "<label>|<args>" ...
cd "$(dirname "$0")/.."
starts() {
  local n=$1; shift
  docker rm -f qr-probe >/dev/null 2>&1
  docker run -d --name qr-probe --gpus all --network host -u $(id -u):$(id -g) -v "$PWD:/work:ro" \
    qr-llama:cuda12.8 /work/bench/serve-tqllm.sh --port 8099 --context $n $ARGS >/dev/null
  local i; for i in $(seq 1 120); do
    docker logs qr-probe 2>&1 | grep -q "listening on" && { docker rm -f qr-probe >/dev/null; return 0; }
    [ "$(docker inspect -f '{{.State.Running}}' qr-probe)" = true ] || break
    sleep 1
  done
  docker logs qr-probe 2>&1 | grep -iE "fit|memory|error" | tail -1 > results/.probe-last
  docker rm -f qr-probe >/dev/null; return 1
}
for cfg in "$@"; do
  label=${cfg%%|*}; ARGS=${cfg#*|}
  lo=0; hi=$((266240 / 4096))  # up to the native 262,144
  while [ $((hi - lo)) -gt 1 ]; do
    mid=$(((lo + hi) / 2))
    if starts $((mid * 4096)); then lo=$mid; else hi=$mid; fi
  done
  echo "$label max_context=$((lo * 4096))  ($(cut -c1-150 results/.probe-last))"
done
