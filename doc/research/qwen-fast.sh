#!/bin/bash
# The fast Qwen3.8-27B server: NInfer-4090 with the DFlash2 drafter (7 draft
# tokens), E8 4-bit KV and 128K context, on http://0.0.0.0:8084/v1 in a container.
# The sampling defaults are those of llama-qwen3.8-27B.sh.
#
# Usage: ./qwen-fast.sh [start|stop|logs] [--vision]
#
# Needs the image qr-ninfer:sm89 (docker build --tag qr-ninfer:sm89 src/ninfer-4090)
# and models/ninfer/qwen3_8_27b_dflash2.ninfer (bench/download-ninfer-dflash.sh).
cd "$(dirname "$0")"
NAME=qwen-fast
case "${1:-start}" in
  stop) docker rm -f $NAME; exit ;;
  logs) docker logs -f $NAME; exit ;;
esac
extra=(); [ "$2" = "--vision" ] && extra=(--vision)
. scripts/common.sh; stop_all
# NVIDIA_DISABLE_REQUIRE: the image is CUDA 13.1, the 580 driver is CUDA 13.0;
# the sm_89 binaries run through minor-version compatibility.
docker run -d --name $NAME --gpus all --network host \
  -e NVIDIA_DISABLE_REQUIRE=1 -v "$PWD/models/ninfer:/models:ro" qr-ninfer:sm89 \
  ninfer-serve /models/qwen3_8_27b_dflash2.ninfer --model-id Qwen3.8-27B \
    --host 0.0.0.0 --port 8084 \
    --max-context 131072 --kv-capacity 131072 --kv-dtype rk4v4-e8 \
    --max-concurrency 1 --max-pending-requests 16 --pending-timeout-ms 600000 \
    --prefill-chunk 1024 --preserve-thinking \
    --spec dflash2 --draft-tokens 7 --lm-head-draft \
    --temperature 0.6 --top-p 0.95 --top-k 20 --min-p 0 --presence-penalty 0 \
    "${extra[@]}"
for i in $(seq 1 60); do curl -sf localhost:8084/health >/dev/null && { echo "ready on http://localhost:8084/v1"; exit 0; }; sleep 3; done
echo "not ready: ./qwen-fast.sh logs"; docker logs --tail 5 $NAME; exit 1
