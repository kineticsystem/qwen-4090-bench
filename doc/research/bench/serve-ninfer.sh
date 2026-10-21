#!/bin/bash
# NInfer-4090 server on the DFlash2-capable artifact. Extra args appended
# (e.g. --spec mtp --draft-tokens 3 --kv-dtype int8).
exec ninfer-serve /work/models/ninfer/qwen3_8_27b_dflash2.ninfer --host 127.0.0.1 --port 8090 \
  --max-concurrency 1 --prefill-chunk 1024 --preserve-thinking "$@"
