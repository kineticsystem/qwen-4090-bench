#!/bin/bash
# Bonsai 2 27B, PrismML's ternary build of Qwen3.8-27B (weights -1, 0 or +1), on upstream
# llama.cpp (llama-cpp-upstream): the Q2_0 file, 7.6 GB, with its own chat template. The
# sampling is the model card's.
#
# Usage: scripts/serve/bonsai.sh [--ctx N] [--port N] [-- llama-server options]
#
#   --         the rest goes to llama-server as it is, after the options above, which it
#              overrides
set -euo pipefail
. "$(dirname "$0")/common.sh"
ctx=32768 extra=()
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --port) PORT=$2; shift 2 ;;
  --) shift; extra=("$@"); break ;;
  *) echo "unknown option $1" >&2; exit 1 ;;
esac; done
need $B/llama-cpp-upstream/bin/llama-server $M/prismml/Ternary-Bonsai-2-27B-Q2_0.gguf
exec $B/llama-cpp-upstream/bin/llama-server -m $M/prismml/Ternary-Bonsai-2-27B-Q2_0.gguf \
  --jinja --alias Ternary-Bonsai-2-27B --n-gpu-layers 999 --ctx-size $ctx --flash-attn on \
  --host 127.0.0.1 --port $PORT --parallel 1 \
  --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.05 "${extra[@]}"
