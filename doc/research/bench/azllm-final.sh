#!/bin/bash
# The remaining azllm measurements, one after the other, with cool-downs.
cd "$(dirname "$0")/.."
B="docker/run.sh qr-llama:cuda12.8 -- python3 /work/bench/bench.py --url http://127.0.0.1:8084 --model Qwen3.8-27B"
echo "#### draft sweep (q8/q4, 128K, text)"
for d in 5 6 8 10; do sleep 30; ./qwen-azllm.sh start --ctx 131072 --no-vision --drafts $d >/dev/null; $B --label "azllm-drafts$d" 2>&1 | grep "^== [a-z]"; done
echo "#### final launcher: speed, accuracy, vision, tool call"
bench/profile-run.sh "prof-azllm-final|qwen-azllm.sh start|kwargs" 2>&1 | grep -vE "CUDA|^$|===="
python3 bench/toolcall-check.py
echo "#### full context"
L="--n-questions 12 --lines 16"
bench/fill-run.sh "azllm-q8q4-242k-vision|qwen-azllm.sh start|237000|$L" \
                  "azllm-q4q4-262k-vision|qwen-azllm.sh start --kv q4/q4 --ctx 262144|257000|$L" 2>&1 | grep -E "^ |^==|prompt tokens"
./qwen-azllm.sh stop
