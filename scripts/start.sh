#!/bin/bash
# The container's command: llama-swap on port 8085, which starts the model servers of
# scripts/serve on demand. Refuses to start, with the reason, when the engines are not
# built or no model has been downloaded.
set -euo pipefail
WS=$(cd "$(dirname "$0")/.." && pwd)
SWAP=$WS/build/llama-swap/llama-swap
[ -x $SWAP ] || { echo "llama-swap is not built: run ./docker/dock.sh build" >&2; exit 1; }
[ -n "$(ls -A /models 2>/dev/null)" ] || { echo "no models in /models: run ./docker/dock.sh models" >&2; exit 1; }
exec $SWAP -config $WS/scripts/llama-swap.yaml -listen 0.0.0.0:8085
