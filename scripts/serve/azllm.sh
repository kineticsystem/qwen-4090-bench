#!/bin/bash
# azllm (a fork of tqLLM): TQ_L weights (4.31 bits per weight), DFlash2 drafter with 7
# draft tokens, prompt cache, and the fixed froggeric v22 chat template (tool calls whose
# arguments arrive as a JSON string fail with the official one).
#
# Usage: scripts/serve/azllm.sh [--ctx N] [--kv q8/q4|q4/q4|q8] [--drafts N] [--no-vision] [--port N]
#   --ctx      context (default 151552, the most q8/q4 fits with vision and 2 GB left free;
#              with q4/q4, 233472)
set -euo pipefail
. "$(dirname "$0")/common.sh"
ctx=151552 kv=q8/q4 drafts=7 vision=(--mmproj "$M/unsloth/mmproj-F16.gguf")
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --kv) kv=$2; shift 2 ;;
  --drafts) drafts=$2; shift 2 ;;
  --no-vision) vision=(); shift ;;
  --port) PORT=$2; shift 2 ;;
  *) echo "unknown option $1" >&2; exit 1 ;;
esac; done
D=$M/tqllm
need $B/azllm/tqserve $D/Qwen3.8-27B-TQ_L.gguf $D/drafters/Qwen3.8-27B-DFlash2-TQ3.gguf \
     $D/mtp-vocab/atx_65536.txt $D/chat_template_v22.jinja "${vision[@]:1}"
# -fitl off: refuse a context that does not fit instead of silently shrinking it.
# -fitt 2048: keep 2 GB of the GPU free after loading. The card also drives the display:
# the desktop holds about 1 GB and grows as windows open, and azllm's CUDA graphs grow
# while it runs. The KV cache does not grow: it is reserved whole at start.
exec $B/azllm/tqserve --model $D/Qwen3.8-27B-TQ_L.gguf -fitt 2048 \
  -md $D/drafters/Qwen3.8-27B-DFlash2-TQ3.gguf --draft-vocab $D/mtp-vocab/atx_65536.txt \
  --draft-max $drafts --chat-template-file $D/chat_template_v22.jinja "${vision[@]}" \
  --context $ctx --kv $kv -fitl off --prompt-cache on \
  --reasoning on --reasoning-effort medium --max-tokens 16384 \
  --name Qwen3.8-27B --host 127.0.0.1 --port $PORT
