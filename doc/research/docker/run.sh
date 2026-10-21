#!/bin/bash
# Run a throw-away container of an image with the GPU, this folder at /work and
# the host's Hugging Face cache (read-only) at /hf.
# Usage: docker/run.sh <image> [docker args...] -- <command...>
image=$1; shift
args=()
while [ $# -gt 0 ] && [ "$1" != "--" ]; do args+=("$1"); shift; done
[ "$1" = "--" ] && shift
exec docker run --rm --gpus all --ipc=host --network host \
  -u $(id -u):$(id -g) -e HOME=/work/.home \
  -v "$(cd "$(dirname "$0")/.." && pwd)":/work \
  -v $HOME/.cache/huggingface:/hf:ro \
  "${args[@]}" "$image" "$@"
