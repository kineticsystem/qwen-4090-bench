#!/bin/bash
# The user's llama-qwen3.8-27B.sh configuration, minus logging and the vision
# projector, in a container. Extra arguments are appended (e.g. overrides).
M=/hf/hub/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502/Qwen3.8-27B-UD-Q4_K_XL.gguf
exec /work/src/llama-cpp-turboquant/build/bin/llama-server -m $M \
  --jinja --chat-template-kwargs '{"reasoning_effort":"medium"}' --alias qwen \
  --n-gpu-layers 999 --ctx-size 128000 --cache-type-k q8_0 --cache-type-v turbo4 \
  --host 127.0.0.1 --port 8090 --reasoning-budget -1 \
  --temp 0.6 --top-p 0.95 --top-k 20 --min-p 0.0 --presence-penalty 0.0 --repeat-penalty 1.0 \
  --flash-attn on --parallel 1 --spec-type draft-mtp --spec-draft-n-max 2 "$@"
