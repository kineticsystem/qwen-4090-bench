#!/bin/bash
# NInfer-4090 with a profile, or with options of your own.
#
# Usage: scripts/serve/ninfer.sh [long|precise|fast] [options]
#   long     176128 context, vision, MTP 3 drafts, rk4v4-e8 KV (4-bit keys and values)  (default)
#   precise  118784 context, vision, MTP 3 drafts, rk8v4 KV (8-bit keys, 4-bit values)
#   fast     77824 context, vision, DFlash2 7 drafts, rk4v4-e8 KV
# The contexts leave 2 GB of the GPU free for the display, with the desktop running; with
# only NInfer's default free memory, the research measured 262144, 204800 and 192512.
# Options after the profile change it:
#   --ctx N, --kv int8|rk8v4|rk4v4-e8, --spec mtp|dflash2|none, --drafts N, --no-vision, --port N
set -euo pipefail
. "$(dirname "$0")/common.sh"
profile=long; case "${1:-}" in long|precise|fast) profile=$1; shift ;; esac
case $profile in
  long)    ctx=176128 kv=rk4v4-e8 spec=mtp     drafts=3 ;;
  precise) ctx=118784 kv=rk8v4    spec=mtp     drafts=3 ;;
  fast)    ctx=77824  kv=rk4v4-e8 spec=dflash2 drafts=7 ;;
esac
vision=(--vision)
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --kv) kv=$2; shift 2 ;;
  --spec) spec=$2; shift 2 ;;
  --drafts) drafts=$2; shift 2 ;;
  --no-vision) vision=(); shift ;;
  --port) PORT=$2; shift 2 ;;
  *) echo "unknown option $1" >&2; exit 1 ;;
esac; done
specargs=(); [ "$spec" != none ] && specargs=(--spec "$spec" --draft-tokens "$drafts" --lm-head-draft)
need $B/ninfer-4090/apps/ninfer-serve $M/ninfer/qwen3_8_27b_dflash2.ninfer
wait_port_free
exec $B/ninfer-4090/apps/ninfer-serve $M/ninfer/qwen3_8_27b_dflash2.ninfer --model-id Qwen3.8-27B \
  --host 127.0.0.1 --port $PORT --max-context $ctx --kv-capacity $ctx --kv-dtype $kv \
  --max-concurrency 1 --max-pending-requests 16 --pending-timeout-ms 600000 \
  --prefill-chunk 1024 --preserve-thinking "${specargs[@]}" "${vision[@]}" \
  --temperature $TEMP --top-p $TOP_P --top-k $TOP_K --min-p $MIN_P --presence-penalty 0
