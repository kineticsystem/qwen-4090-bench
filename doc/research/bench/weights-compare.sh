#!/bin/bash
# Code NLL of the three weight files on the same positions: 4 chunks of 64K tokens,
# last 32K of each scored (llama-perplexity -c 65536's protocol; NInfer windows 2, 4, 6
# of --context 65536 --stride 32768 score the same positions as chunks 1-3).
cd "$(dirname "$0")/.."
G=/hf/hub/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502/Qwen3.8-27B-UD-Q4_K_XL.gguf
F='^$|CUDA Version|NVIDIA|container|license|===='
echo "== azllm TQ_L, q8 KV, FP16 prefill"
docker/run.sh qr-llama:cuda12.8 -- /work/src/azllm/build/tqkld --model /work/models/tqllm/Qwen3.8-27B-TQ_L.gguf \
  --tail 32768 --ref /work/results/tqkld/ref-q8 --out /work/results/tqkld/q8-fp16prefill --kv q8 --prefill-int8 off 2>&1 | grep -vE "$F" | tail -5
sleep 60
echo "== llama.cpp UD-Q4_K_XL, q8_0/q8_0"
docker/run.sh qr-llama:cuda12.8 -- /work/src/llama-cpp-turboquant/build/bin/llama-perplexity -m $G \
  -f /work/datasets/code_ppl.txt -c 65536 -b 2048 -ub 1024 -ngl 999 -fa on --cache-type-k q8_0 --cache-type-v q8_0 \
  > results/ppl-llama-q8q8-full.txt 2>&1; grep -oE "\[[0-9]\][0-9.]+|Final estimate.*" results/ppl-llama-q8q8-full.txt | tr '\n' ' '; echo
sleep 60
echo "== NInfer, int8 KV"
docker run --rm --gpus all -e NVIDIA_DISABLE_REQUIRE=1 -v $PWD:/work qr-ninfer-build:sm89 bash -c "
  rm -rf /usr/local/cuda*/compat; rm -rf /work/results/ppl-ninfer-int8-64k
  /work/bin/ninfer-perplexity /work/models/ninfer/qwen3_8_27b_dflash2.ninfer --text /work/datasets/code_ppl.txt \
    --context 65536 --stride 32768 --kv-dtype int8 --output /work/results/ppl-ninfer-int8-64k 2>&1 | grep overall
  chown -R $(id -u):$(id -g) /work/results/ppl-ninfer-int8-64k"
