#!/bin/bash
# Download every model into /models (../models on the host, or $MODELS_DIR), each pinned to
# the revision that was measured and checked against its SHA-256. Interrupted downloads
# resume; files already there and correct are skipped. About 54 GB in total.
#
#   unsloth/  Qwen3.8-27B-UD-Q4_K_XL.gguf, 17.6 GB  baseline and OpenJet
#             mmproj-F16.gguf, 0.9 GB               vision, baseline and azllm
#   ninfer/   qwen3_8_27b_dflash2.ninfer, 20.4 GB   NInfer, with its DFlash2 drafter
#   tqllm/    Qwen3.8-27B-TQ_L.gguf, 14.7 GB        azllm
#             drafters/, mtp-vocab/                 azllm's DFlash2 drafter, 0.8 GB
#             chat_template_v22.jinja               the fixed chat template of TQ3_4S-v2
set -euo pipefail
M=${MODELS:-/models}
HF=https://huggingface.co

# get <url> <file> [sha256]
get() {
  local url=$1 out=$M/$2 sha=${3:-}
  mkdir -p "$(dirname "$out")"
  if [ -f "$out.ok" ]; then echo "== $2: already downloaded"; return; fi
  echo "== $2"
  curl -L --fail -C - --retry 5 --progress-bar -o "$out" "$url"
  if [ -n "$sha" ]; then
    echo "   checking SHA-256..."
    echo "$sha  $out" | sha256sum --check --status || { echo "SHA-256 mismatch for $out" >&2; exit 1; }
  fi
  touch "$out.ok"
}

U=$HF/unsloth/Qwen3.8-27B-GGUF/resolve/4ca720788d1e01f1bff70c033e0d0028fd02e502
get $U/Qwen3.8-27B-UD-Q4_K_XL.gguf unsloth/Qwen3.8-27B-UD-Q4_K_XL.gguf \
    3f227079003add2511437e5b1e94812e363385225bf6a9b47b0054a72bc8b01e
get $U/mmproj-F16.gguf unsloth/mmproj-F16.gguf \
    cbb841a9ee0636b2ec172f5bb8df2ea8dfeb01e90fe7c6126581d662a0b4e43e

# Container v2, the format NInfer-4090 reads; the main revision moved to v3.
get $HF/neroued/Qwen3.8-27B-NInfer/resolve/dc370fb6295a/qwen3_8_27b.ninfer ninfer/qwen3_8_27b_dflash2.ninfer \
    0634abb07024221de141456cf04a42ab74b18bc38e1b781c6eb2e062a467eec3

T=$HF/YTan2000/Qwen3.8-27B-TQ/resolve/4a74bae323adaab36d40d4b8e49b5a1b02a6faf6
get $T/Qwen3.8-27B-TQ_L.gguf tqllm/Qwen3.8-27B-TQ_L.gguf \
    0ab0f05816b595e34bcafd25bbbe0c3d247cab056a7aab99ccab7e5454e6e4b2
get $T/drafters/Qwen3.8-27B-DFlash2-TQ3.gguf tqllm/drafters/Qwen3.8-27B-DFlash2-TQ3.gguf \
    7f12a657b8c039f6748eb665c650fd0de47284cd8975847fa4e6757cf77a07bd
get $T/mtp-vocab/atx_65536.txt tqllm/mtp-vocab/atx_65536.txt

# The fixed chat template is embedded in the TQ3_4S-v2 file: read it from the first 40 MB,
# the GGUF header, instead of downloading 14.5 GB.
if [ ! -f $M/tqllm/chat_template_v22.jinja ]; then
  echo "== tqllm/chat_template_v22.jinja"
  python3 "$(dirname "$0")/tools/gguf-template.py" \
    $HF/YTan2000/Qwen3.8-27B-TQ3_4S/resolve/a07bc6f260d1a431a38f5332fd8fc512ff7b871f/Qwen3.8-27B-TQ3_4S-v2.gguf \
    $M/tqllm/chat_template_v22.jinja
fi
echo "== models ready in $M"
