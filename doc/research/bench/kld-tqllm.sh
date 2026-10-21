#!/bin/bash
# Code NLL and KL divergence of azllm's KV formats on 4 chunks of 64K tokens, scoring the
# last 32K of each (the positions llama-perplexity -c 65536 scores).
# First dumps a q8-KV reference, then scores each format against it.
cd "$(dirname "$0")/.."
R=/work/results/tqkld; M=/work/models/tqllm/Qwen3.8-27B-TQ_L.gguf
run() { docker/run.sh qr-llama:cuda12.8 -- /work/src/azllm/build/tqkld --model $M --tail 32768 "$@" 2>&1 \
          | grep -vE "^$|CUDA Version|NVIDIA|container|license|====" ; }
[ -f results/tqkld/ref-q8/meta.json ] || { mkdir -p results/tqkld/ref-q8; run --ref $R/ref-dummy --dump-ref $R/ref-q8 --kv q8 | tail -2; }
for kv in "$@"; do
  sleep 60  # cool-down
  run --ref $R/ref-q8 --out $R/${kv//\//-} --kv $kv | tail -8 | sed "s|^|$kv: |"
done
