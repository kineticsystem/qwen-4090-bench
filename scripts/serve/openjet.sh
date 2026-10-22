#!/bin/bash
# OpenJet Engine (persistent megakernel, MTP drafts) on Unsloth's UD-Q4_K_XL GGUF. Text only.
#
# Usage: scripts/serve/openjet.sh [--ctx N] [--kv q8|f16] [--drafts N] [--port N]
#   --ctx     context (default 65536, the most that leaves 2 GB of the GPU free for the
#             display; on a card that drives no display, 147456 fits, with smaller
#             prefill chunks, chosen automatically above 131072)
#   --kv      q8 (default) or f16 (at most 69632 tokens)
#   --drafts  MTP drafts per step, 0-4 (default 4)
set -euo pipefail
. "$(dirname "$0")/common.sh"
ctx=65536 kv=q8 drafts=4
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --kv) kv=$2; shift 2 ;;
  --drafts) drafts=$2; shift 2 ;;
  --port) PORT=$2; shift 2 ;;
  *) echo "unknown option $1" >&2; exit 1 ;;
esac; done
K=$E/open-jet/megakernel
need $K/libqwen38mk_mixed.so $M/unsloth/Qwen3.8-27B-UD-Q4_K_XL.gguf
# Above 128K the prefill scratch must shrink to leave room for the KV cache.
export MK_PF_CAP=2048
[ $ctx -gt 131072 ] && MK_PF_CAP=1024
[ $ctx -gt 139264 ] && MK_PF_CAP=512
cd $K
exec python3 server/mk_server.py -m $M/unsloth/Qwen3.8-27B-UD-Q4_K_XL.gguf \
  --lib ./libqwen38mk_mixed.so --host 127.0.0.1 --port $PORT -c $ctx --kv $kv -d $drafts
