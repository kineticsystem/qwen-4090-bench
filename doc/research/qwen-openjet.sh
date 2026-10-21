#!/bin/bash
# OpenJet Engine (megakernel) on the same UD-Q4_K_XL GGUF as the baseline. Text only.
#
# Usage: ./qwen-openjet.sh start|run [--ctx N] [--kv q8|f16] [--drafts N] | stop | logs
#   --ctx     context in tokens (default 131072; 147456 is the most that starts,
#             with smaller prefill chunks, set automatically above 131072)
#   --kv      KV cache: q8 (default) or f16 (at most 69632 tokens)
#   --drafts  MTP drafts per step, 0-4 (default 4)
cd "$(dirname "$0")"; . scripts/common.sh
NAME=qwen-openjet
handle_command $NAME "${1:-start}"; shift
ctx=131072 kv=q8 drafts=4
while [ $# -gt 0 ]; do case "$1" in
  --ctx) ctx=$2; shift 2 ;;
  --kv) kv=$2; shift 2 ;;
  --drafts) drafts=$2; shift 2 ;;
  --port) PORT=$2; shift 2 ;;
  *) echo "unknown option $1"; exit 1 ;;
esac; done
# Above 128K the prefill scratch must shrink to leave room for the KV cache.
pfcap=2048; [ $ctx -gt 131072 ] && pfcap=1024; [ $ctx -gt 139264 ] && pfcap=512
stop_all
docker_run $NAME --gpus all --network host -u $(id -u):$(id -g) \
  -e HOME=/work/.home -e MK_PF_CAP=$pfcap \
  -v "$PWD:/work" -v $HOME/.cache/huggingface:/hf:ro qr-llama:cuda12.8 \
  /work/bench/serve-openjet.sh --host 0.0.0.0 --port $PORT -c $ctx --kv $kv -d $drafts
