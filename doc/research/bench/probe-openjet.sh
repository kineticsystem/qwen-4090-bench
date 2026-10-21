#!/bin/bash
# Binary-search the largest -c (context) that OpenJet starts with, per configuration.
# Usage: bench/probe-openjet.sh "<label>|<args>" ...
cd "$(dirname "$0")/.."
starts() {
  local n=$1; shift
  docker rm -f qr-probe >/dev/null 2>&1
  docker run -d --name qr-probe --gpus all --network host -u $(id -u):$(id -g) -e HOME=/work/.home \
    -v "$PWD:/work" -v $HOME/.cache/huggingface:/hf:ro $DOCKER_ENV qr-llama:cuda12.8 \
    /work/bench/serve-openjet.sh --port 8099 -c $n $ARGS >/dev/null
  local i; for i in $(seq 1 120); do
    docker logs qr-probe 2>&1 | grep -q "listening on" && { docker rm -f qr-probe >/dev/null; return 0; }
    [ "$(docker inspect -f '{{.State.Running}}' qr-probe)" = true ] || break
    sleep 1
  done
  docker logs qr-probe 2>&1 | grep -iE "error|memory" | tail -1 >&2
  docker rm -f qr-probe >/dev/null; return 1
}
for cfg in "$@"; do
  label=${cfg%%|*}; ARGS=${cfg#*|}
  lo=0; hi=$((524288 / 4096))
  while [ $((hi - lo)) -gt 1 ]; do
    mid=$(((lo + hi) / 2))
    if starts $((mid * 4096)) 2>/dev/null; then lo=$mid; else hi=$mid; fi
  done
  echo "$label max_context=$((lo * 4096))"
done
