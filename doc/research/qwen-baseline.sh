#!/bin/bash
# The original setup, llama-qwen3.8-27B.sh, in a container: llama-cpp-turboquant,
# UD-Q4_K_XL GGUF, MTP with 2 drafts, KV q8_0/turbo4, 128K context, vision on CPU.
#
# Usage: ./qwen-baseline.sh start|run [--ctx N] [--no-vision] | stop | logs
cd "$(dirname "$0")"; . scripts/common.sh
NAME=qwen-baseline
handle_command $NAME "${1:-start}"; shift
ctx=128000; vision=(--mmproj /hf/hub/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502/mmproj-BF16.gguf --no-mmproj-offload)
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --no-vision) vision=(); shift ;;
  --port) PORT=$2; shift 2 ;;
  *) echo "unknown option $1"; exit 1 ;;
esac; done
stop_all
docker_run $NAME --gpus all --network host -u $(id -u):$(id -g) \
  -v "$PWD:/work:ro" -v $HOME/.cache/huggingface:/hf:ro qr-llama:cuda12.8 \
  /work/src/llama-cpp-turboquant/build/bin/llama-server \
    -m /hf/hub/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502/Qwen3.8-27B-UD-Q4_K_XL.gguf \
    "${vision[@]}" --jinja --chat-template-kwargs '{"reasoning_effort":"medium"}' --alias Qwen3.8-27B \
    --n-gpu-layers 999 --ctx-size $ctx --cache-type-k q8_0 --cache-type-v turbo4 \
    --host 0.0.0.0 --port $PORT --reasoning-budget -1 \
    --temp 0.6 --top-p 0.95 --top-k 20 --min-p 0.0 --presence-penalty 0.0 --repeat-penalty 1.0 \
    --flash-attn on --parallel 1 --spec-type draft-mtp --spec-draft-n-max 2
