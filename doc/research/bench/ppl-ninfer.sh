#!/bin/bash
# Code perplexity of NInfer per KV type. Usage: bench/ppl-ninfer.sh <context> <stride> <kv>...
# The build image holds CUDA forward-compatibility libraries, which GeForce cards
# reject: the throw-away container removes them first.
cd "$(dirname "$0")/.."
ctx=$1 stride=$2; shift 2
for kv in "$@"; do
  sleep 60  # cool-down: the machine reset once during back-to-back runs
  docker run --rm --gpus all -e NVIDIA_DISABLE_REQUIRE=1 -v $PWD:/work qr-ninfer-build:sm89 bash -c "
    rm -rf /usr/local/cuda*/compat; /work/bin/ninfer-perplexity /work/models/ninfer/qwen3_8_27b_dflash2.ninfer \
    --text /work/datasets/code_ppl.txt --context $ctx --stride $stride --kv-dtype $kv \
    --output /tmp/ppl-out-$kv 2>&1; cat /tmp/ppl-out-$kv/report.json 2>/dev/null | head -c 0" \
    | grep -vE '^$|CUDA|NVIDIA|container|license|====|progress|scoring [0-9]' | tail -6 | sed "s/^/$kv ctx=$ctx: /"
done
