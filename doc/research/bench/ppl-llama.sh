#!/bin/bash
# Code perplexity of llama-cpp-turboquant per KV type, same text as bench/ppl-ninfer.sh.
# Usage: bench/ppl-llama.sh <context> "<K>/<V>"...
cd "$(dirname "$0")/.."
ctx=$1; shift
M=/hf/hub/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502/Qwen3.8-27B-UD-Q4_K_XL.gguf
for kv in "$@"; do
  sleep 60  # cool-down: the machine reset once during back-to-back runs
  docker/run.sh qr-llama:cuda12.8 -- /work/src/llama-cpp-turboquant/build/bin/llama-perplexity -m $M \
    -f /work/datasets/code_ppl.txt -c $ctx -b 2048 -ub 1024 -ngl 999 -fa on \
    --cache-type-k ${kv%/*} --cache-type-v ${kv#*/} 2>&1 | grep -E "Final estimate|error|failed" | sed "s|^|$kv ctx=$ctx: |"
done
