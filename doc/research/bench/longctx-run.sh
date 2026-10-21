#!/bin/bash
# For each configuration: start the server, run the long-context precision test.
# Usage: bench/longctx-run.sh "<label>|<image>|<serve script>|<server args>|<prompt tokens>|<longctx args>" ...
cd "$(dirname "$0")/.."
for cfg in "$@"; do
  IFS='|' read -r label image serve sargs tokens largs <<< "$cfg"
  docker rm -f qr-server >/dev/null 2>&1; sleep 5
  docker/run.sh $image -d --name qr-server -e NVIDIA_DISABLE_REQUIRE=1 $DOCKER_ENV -- $serve $sargs >/dev/null
  for i in $(seq 1 120); do curl -sf localhost:8090/health >/dev/null && break; docker ps -q -f name=qr-server | grep -q . || break; sleep 3; done
  if ! curl -sf localhost:8090/health >/dev/null; then echo "== $label: SERVER DID NOT START"; continue; fi
  docker/run.sh qr-llama:cuda12.8 -- python3 /work/bench/longctx.py --label "$label" --tokens $tokens $largs 2>&1 | grep -E "^ |^==|prompt tokens|Error|error"
  docker ps -q -f name=qr-server | grep -q . || echo "== $label: SERVER CRASHED"
done
docker rm -f qr-server >/dev/null 2>&1
