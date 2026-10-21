#!/bin/bash
# Restart the NInfer server with each configuration and run the sampling benchmark.
# Usage: bench/sweep-ninfer.sh "<label>|<server args>" ...
cd "$(dirname "$0")/.."
for cfg in "$@"; do
  label=${cfg%%|*}; args=${cfg#*|}
  docker rm -f qr-server >/dev/null 2>&1
  docker/run.sh qr-ninfer:sm89 -d --name qr-server -e NVIDIA_DISABLE_REQUIRE=1 -- /work/bench/serve-ninfer.sh $args >/dev/null
  for i in $(seq 1 90); do curl -sf localhost:8090/health >/dev/null && break; docker ps -q -f name=qr-server | grep -q . || break; sleep 3; done
  if ! curl -sf localhost:8090/health >/dev/null; then echo "$label: FAILED"; docker logs qr-server 2>&1 | grep -iE "error|fatal" | tail -3; continue; fi
  docker/run.sh qr-llama:cuda12.8 -- python3 /work/bench/bench.py --model qwen3.8-27b --no-think top --label "$label" ${BENCH_ARGS} 2>&1 | grep "^=="
done
