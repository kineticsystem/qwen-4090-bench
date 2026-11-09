#!/bin/bash
# Bonsai 2 27B on NInfer, with MTP and host n-gram drafts: JGamboa's fork reads the ternary
# weights, and its artifact carries Qwen3.8-27B's MTP layer, retrained on Bonsai's outputs.
#
# NInfer refuses JSON schemas (response_format other than text), so a client that needs one
# has to validate the answer itself and ask again.
#
# Usage: scripts/serve/bonsai-ninfer.sh [--ctx N] [--kv TYPE] [--drafts N] [--ngram chain|off] [--port N] [-- ninfer-serve options]
#   --ctx     context (default 253952, 254K, with the 4-bit KV)
#   --drafts  MTP drafts per step (default 3)
#   --ngram   chain extends the MTP drafts with n-gram drafts: helps JSON and edits, not prose
#   --kv      KV cache type (default rk4v4-e8)
#   --        the rest goes to ninfer-serve as it is
set -euo pipefail
. "$(dirname "$0")/common.sh"
ctx=253952 kv=rk4v4-e8 drafts=3 ngram=chain extra=()
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --kv) kv=$2; shift 2 ;;
  --drafts) drafts=$2; shift 2 ;;
  --ngram) ngram=$2; shift 2 ;;
  --port) PORT=$2; shift 2 ;;
  --) shift; extra=("$@"); break ;;
  *) echo "unknown option $1" >&2; exit 1 ;;
esac; done
F=$M/ninfer-bonsai/bonsai2_27b_vl_mtp_retrained.ninfer
need $B/ninfer-bonsai/apps/ninfer-serve $F
# A short key, 4 tokens, is the fastest on new text: 350 tok/s on code, against 312 with the default 8.
ngramargs=(); [ "$ngram" = off ] || ngramargs=(--ngram "$ngram" --ngram-n 4)
wait_port_free
exec $B/ninfer-bonsai/apps/ninfer-serve $F --model-id Ternary-Bonsai-2-27B \
  --host 127.0.0.1 --port $PORT --max-context $ctx --kv-capacity $ctx --kv-dtype $kv \
  --max-concurrency 1 --max-pending-requests 16 --pending-timeout-ms 600000 \
  --prefill-chunk 1024 --spec mtp --draft-tokens "$drafts" --lm-head-draft "${ngramargs[@]}" \
  --no-thinking --temperature 0.4 --top-p 0.95 --top-k 20 --min-p 0.05 --presence-penalty 0 "${extra[@]}"
