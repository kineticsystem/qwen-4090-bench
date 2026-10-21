#!/bin/bash
# NInfer-4090 with a profile, or with options of your own.
#
# Usage: ./qwen-ninfer.sh start|run [profile] [options] | stop | logs
#
# Profiles:
#   long     256K context, vision, MTP 3 drafts, 4-bit E8 KV            (default)
#   fast     192K context, vision, DFlash2 7 drafts, 4-bit E8 KV
#   precise  200K context, vision, MTP 3 drafts, 8-bit keys / 4-bit values (rk8v4),
#            the closest to the baseline's q8_0 / turbo4
#
# Options, after the profile, override it:
#   --ctx N          context in tokens
#   --kv TYPE        int8 | rk8v4 | rk4v4-e8 | rk2v4-e8 | bf16
#   --spec SPEC      mtp | dflash2 | none
#   --drafts N       draft tokens per step
#   --no-vision      text only (frees about 0.5-1.5 GB for context)
cd "$(dirname "$0")"; . scripts/common.sh
NAME=qwen-ninfer
handle_command $NAME "${1:-start}"; shift
profile=long; case "$1" in long|fast|precise) profile=$1; shift ;; esac
case $profile in
  long)    ctx=262144 kv=rk4v4-e8 spec=mtp     drafts=3 ;;
  fast)    ctx=192512 kv=rk4v4-e8 spec=dflash2 drafts=7 ;;
  precise) ctx=204800 kv=rk8v4    spec=mtp     drafts=3 ;;
esac
vision=(--vision)
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --kv) kv=$2; shift 2 ;;
  --spec) spec=$2; shift 2 ;;
  --drafts) drafts=$2; shift 2 ;;
  --no-vision) vision=(); shift ;;
  --port) PORT=$2; shift 2 ;;
  *) echo "unknown option $1"; exit 1 ;;
esac; done
specargs=(); [ "$spec" != none ] && specargs=(--spec $spec --draft-tokens $drafts --lm-head-draft)
stop_all
echo "profile $profile: ctx $ctx, kv $kv, spec $spec ($drafts drafts), ${vision[*]:-no vision}"
# NVIDIA_DISABLE_REQUIRE: the image is CUDA 13.1, the 580 driver is CUDA 13.0;
# the sm_89 binaries run through minor-version compatibility.
docker_run $NAME --gpus all --network host -e NVIDIA_DISABLE_REQUIRE=1 \
  -v "$PWD/models/ninfer:/models:ro" qr-ninfer:sm89 \
  ninfer-serve /models/qwen3_8_27b_dflash2.ninfer --model-id Qwen3.8-27B \
    --host 0.0.0.0 --port $PORT --max-context $ctx --kv-capacity $ctx --kv-dtype $kv \
    --max-concurrency 1 --max-pending-requests 16 --pending-timeout-ms 600000 \
    --prefill-chunk 1024 --preserve-thinking "${specargs[@]}" "${vision[@]}" \
    --temperature 0.6 --top-p 0.95 --top-k 20 --min-p 0 --presence-penalty 0
