#!/bin/bash
# The reference baseline: llama.cpp with the TurboQuant KV types (llama-cpp-turboquant) on
# Unsloth's UD-Q4_K_XL GGUF, MTP with 2 drafts, q8_0 keys and turbo4 values, 128K context,
# vision projector in host memory. It leaves about 2.3 GB of the GPU free for the display.
#
# Usage: scripts/serve/baseline.sh [--ctx N] [--no-vision] [--port N]
set -euo pipefail
. "$(dirname "$0")/common.sh"
ctx=128000 vision=(--mmproj "$M/unsloth/mmproj-F16.gguf" --no-mmproj-offload)
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --no-vision) vision=(); shift ;;
  --port) PORT=$2; shift 2 ;;
  *) echo "unknown option $1" >&2; exit 1 ;;
esac; done
need $B/llama-cpp-turboquant/bin/llama-server $M/unsloth/Qwen3.8-27B-UD-Q4_K_XL.gguf
exec $B/llama-cpp-turboquant/bin/llama-server -m $M/unsloth/Qwen3.8-27B-UD-Q4_K_XL.gguf \
  "${vision[@]}" --jinja --chat-template-kwargs '{"reasoning_effort":"medium"}' --alias Qwen3.8-27B \
  --n-gpu-layers 999 --ctx-size $ctx --cache-type-k q8_0 --cache-type-v turbo4 \
  --host 127.0.0.1 --port $PORT --reasoning-budget -1 \
  --temp $TEMP --top-p $TOP_P --top-k $TOP_K --min-p $MIN_P --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on --parallel 1 --spec-type draft-mtp --spec-draft-n-max 2
