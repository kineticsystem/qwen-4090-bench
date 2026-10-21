#!/bin/bash
# Restart a server container with each configuration and run the sampling benchmark.
# Usage: bench/sweep-server.sh <image> <serve script> <bench args> "<label>|<server args>" ...
cd "$(dirname "$0")/.."
image=$1 serve=$2 bargs=$3; shift 3
for cfg in "$@"; do
  label=${cfg%%|*}; args=${cfg#*|}
  docker rm -f qr-server >/dev/null 2>&1; sleep 5
  docker/run.sh $image -d --name qr-server -e NVIDIA_DISABLE_REQUIRE=1 -- $serve $args >/dev/null
  for i in $(seq 1 120); do curl -sf localhost:8090/health >/dev/null && break; docker ps -q -f name=qr-server | grep -q . || break; sleep 3; done
  if ! curl -sf localhost:8090/health >/dev/null; then echo "$label: FAILED"; continue; fi
  docker/run.sh qr-llama:cuda12.8 -- python3 /work/bench/bench.py --label "$label" $bargs ${BENCH_ARGS} 2>&1 | grep "^== [a-z]"
done
