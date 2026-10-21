#!/bin/bash
# azllm (a fork of tqllm): TQ_L weights (4.31 bits per weight), DFlash2 drafter,
# prompt cache, and the fixed froggeric v22 chat template (tool calls whose arguments
# arrive as a JSON string fail with the official one). Port 8084.
#
# Usage: ./qwen-azllm.sh start|run [options] | stop | logs
#   --ctx N        context in tokens (default 241664, the most q8/q4 KV fits with vision;
#                  262144 needs --kv q4/q4)
#   --kv FORMAT    q8/q4 (default: 8-bit keys, 4-bit values), q8, q4/q4
#   --no-vision    text only
#   --drafts N     DFlash2 draft tokens per step (default 7)
cd "$(dirname "$0")"; . scripts/common.sh
NAME=qwen-azllm
handle_command $NAME "${1:-start}"; shift
ctx=241664 kv=q8/q4 drafts=7 vision=(--mmproj /work/models/tqllm/mmproj-F16.gguf)
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --kv) kv=$2; shift 2 ;;
  --drafts) drafts=$2; shift 2 ;;
  --no-vision) vision=(); shift ;;
  --port) PORT=$2; shift 2 ;;
  *) echo "unknown option $1"; exit 1 ;;
esac; done
stop_all
echo "azllm: ctx $ctx, kv $kv, DFlash2 $drafts drafts, ${vision[*]:+vision}"
docker_run $NAME --gpus all --network host -u $(id -u):$(id -g) \
  -v "$PWD:/work:ro" qr-llama:cuda12.8 \
  /work/bench/serve-tqllm.sh --name Qwen3.8-27B --host 0.0.0.0 --port $PORT \
    --context $ctx --kv $kv --draft-max $drafts "${vision[@]}" \
    --chat-template-file /work/models/tqllm/templates/chat_template_v22.jinja
