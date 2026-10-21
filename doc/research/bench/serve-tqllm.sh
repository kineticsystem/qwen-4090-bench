#!/bin/bash
# azllm (tqllm fork) server: TQ_L weights, DFlash2 drafter, prompt cache. Extra args appended
# (e.g. --context 262144 --kv q8/q4 --mmproj /work/models/tqllm/mmproj-BF16.gguf).
D=/work/models/tqllm
exec /work/src/azllm/build/tqserve --model ${TQ_MODEL:-$D/Qwen3.8-27B-TQ_L.gguf} \
  -md $D/drafters/Qwen3.8-27B-DFlash2-TQ3.gguf --draft-vocab $D/mtp-vocab/atx_65536.txt \
  --prompt-cache on --reasoning on --reasoning-effort medium --max-tokens 16384 \
  --name qwen --host 127.0.0.1 --port 8090 -fitl off "$@"
