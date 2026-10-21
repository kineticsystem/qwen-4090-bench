#!/bin/bash
# Start a launcher, fill its context to near the limit with code, ask recall
# questions, then check that the server is still alive and still sees images.
# Usage: bench/fill-run.sh "<label>|<launcher and its args>|<prompt tokens>|<longctx args>" ...
cd "$(dirname "$0")/.."
for cfg in "$@"; do
  IFS='|' read -r label launcher tokens largs <<< "$cfg"
  sleep 60  # cool-down: the machine reset once during back-to-back runs
  ./$launcher | tail -1
  curl -sf localhost:8084/health >/dev/null || { echo "== $label: DID NOT START"; continue; }
  docker/run.sh qr-llama:cuda12.8 -- python3 /work/bench/longctx.py --url http://127.0.0.1:8084 \
    --model Qwen3.8-27B --label "$label" --tokens $tokens $largs 2>&1 | grep -E "^ |^==|prompt tokens|Error|error"
  if curl -sf localhost:8084/health >/dev/null; then echo "== $label: server alive"; else echo "== $label: SERVER DIED"; fi
  python3 bench/vision-check.py 2>&1 | sed "s/^/== $label: vision: /"
done
