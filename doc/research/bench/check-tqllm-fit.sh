#!/bin/bash
# Start azllm with the given args and print what its memory fit moved to host memory.
cd "$(dirname "$0")/.."
docker rm -f qr-probe >/dev/null 2>&1
docker run -d --name qr-probe --gpus all --network host -u $(id -u):$(id -g) -v "$PWD:/work:ro" \
  qr-llama:cuda12.8 /work/bench/serve-tqllm.sh --port 8099 "$@" >/dev/null
for i in $(seq 1 120); do
  docker logs qr-probe 2>&1 | grep -q "listening on" && break
  [ "$(docker inspect -f '{{.State.Running}}' qr-probe)" = true ] || break; sleep 1
done
state=$(docker logs qr-probe 2>&1 | grep -q "listening on" && echo started || echo FAILED)
host=$(docker logs qr-probe 2>&1 | grep -iE "host memory" | sed 's/^tq[a-z]*: //' | tr '\n' ';' | cut -c1-250)
echo "$* => $state | ${host:-everything on GPU}"
docker rm -f qr-probe >/dev/null; sleep 3
