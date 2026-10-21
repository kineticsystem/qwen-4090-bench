#!/bin/bash
# The NInfer Qwen3.8-27B artifact with the DFlash2 drafter weights (container v2).
set -e
out=/home/robot/repo/qwen-research/models/ninfer/qwen3_8_27b_dflash2.ninfer
curl -sS -L -C - --fail --output $out \
  "https://huggingface.co/neroued/Qwen3.8-27B-NInfer/resolve/dc370fb6295a/qwen3_8_27b.ninfer"
echo "0634abb07024221de141456cf04a42ab74b18bc38e1b781c6eb2e062a467eec3  $out" | sha256sum -c
