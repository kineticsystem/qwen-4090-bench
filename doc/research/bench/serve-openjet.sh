#!/bin/bash
# OpenJet megakernel engine on the user's UD-Q4_K_XL GGUF. Extra args appended.
M=/hf/hub/models--unsloth--Qwen3.8-27B-GGUF/snapshots/4ca720788d1e01f1bff70c033e0d0028fd02e502/Qwen3.8-27B-UD-Q4_K_XL.gguf
cd /work/src/open-jet/megakernel
exec python3 server/mk_server.py -m $M --lib ./libqwen38mk_mixed.so --host 127.0.0.1 --port 8090 "$@"
