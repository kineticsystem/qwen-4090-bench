#!/bin/bash
# Compile every engine for the RTX 4090 (sm_89), inside the container. Each engine is a
# Git submodule in engines/; its build goes to build/<engine>, except where the engine
# builds in its own tree: llama.cpp (OpenJet's Makefile expects engines/llama.cpp/build),
# OpenJet itself, and llama-swap's web UI.
#
# Usage: scripts/build.sh [--force] [engine...]
#   engine   llama.cpp, llama-cpp-turboquant, open-jet, ninfer-4090, azllm, llama-swap
#            (default: all, in that order: OpenJet needs llama.cpp)
#   --force  rebuild even when the engine's binary is already there
set -euo pipefail
WS=$(cd "$(dirname "$0")/.." && pwd)
E=$WS/engines B=$WS/build
JOBS=$(nproc)
force=0; engines=()
for a in "$@"; do [ "$a" = --force ] && force=1 || engines+=("$a"); done
[ ${#engines[@]} -gt 0 ] || engines=(llama.cpp llama-cpp-turboquant open-jet ninfer-4090 azllm llama-swap)

# Skip an engine whose output already exists, unless --force.
built() { [ $force = 0 ] && [ -e "$1" ] && echo "== $2: already built ($1)"; }

for engine in "${engines[@]}"; do
  case $engine in
    llama.cpp)
      # Only libllama, which OpenJet loads to tokenize (vocabulary only): no CUDA needed.
      built $E/llama.cpp/build/bin/libllama.so llama.cpp && continue
      echo "== llama.cpp (tokenizer library for OpenJet)"
      cmake -S $E/llama.cpp -B $E/llama.cpp/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DGGML_CUDA=OFF -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_SERVER=OFF
      cmake --build $E/llama.cpp/build -j $JOBS --target llama ;;
    llama-cpp-turboquant)
      built $B/llama-cpp-turboquant/bin/llama-server llama-cpp-turboquant && continue
      echo "== llama-cpp-turboquant (the baseline)"
      cmake -S $E/llama-cpp-turboquant -B $B/llama-cpp-turboquant -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89 \
        -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF
      cmake --build $B/llama-cpp-turboquant -j $JOBS --target llama-server ;;
    open-jet)
      built $E/open-jet/megakernel/libqwen38mk_mixed.so open-jet && continue
      echo "== OpenJet (the mixed-quant engine reads UD-Q4_K_XL; about 11 GB of RAM to compile)"
      make -C $E/open-jet/megakernel LLAMA=$E/llama.cpp ARCH=sm_89 NVCC=/usr/local/cuda/bin/nvcc \
        -j1 libqwen38mk_mixed.so ;;
    ninfer-4090)
      built $B/ninfer-4090/apps/ninfer-serve ninfer-4090 && continue
      echo "== NInfer-4090"
      cmake -S $E/ninfer-4090 -B $B/ninfer-4090 -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DNINFER_BUILD_APPS=ON -DBUILD_TESTING=OFF -DNINFER_BUILD_BENCHMARKS=OFF
      cmake --build $B/ninfer-4090 -j $JOBS --target ninfer-serve ;;
    azllm)
      built $B/azllm/tqserve azllm && continue
      echo "== azllm"
      cmake -S $E/azllm -B $B/azllm -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CUDA_ARCHITECTURES=89
      cmake --build $B/azllm -j $JOBS --target tqserve ;;
    llama-swap)
      built $B/llama-swap/llama-swap llama-swap && continue
      echo "== llama-swap (web UI, then the Go binary with the UI embedded)"
      (cd $E/llama-swap/ui && npm ci --no-audit --no-fund && npm run build)
      mkdir -p $B/llama-swap
      (cd $E/llama-swap && go build -tags embed_ui \
        -ldflags="-X main.commit=$(git rev-parse --short HEAD) -X main.version=qwen-4090-bench" \
        -o $B/llama-swap/llama-swap .) ;;
    *) echo "unknown engine: $engine" >&2; exit 1 ;;
  esac
done
echo "== build done"
