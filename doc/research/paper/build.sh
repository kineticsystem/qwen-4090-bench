#!/bin/bash
# Build the paper in a throw-away LaTeX container and copy it next to REPORT.md.
# The image is built from ../docker/Dockerfile.latex the first time.
set -e
cd "$(dirname "$0")"
PDF="../Serving-Qwen3.8-27B-on-a-single-RTX-4090.pdf"
docker image inspect qr-latex >/dev/null 2>&1 || docker build -t qr-latex -f ../docker/Dockerfile.latex ../docker
docker run --rm -u $(id -u):$(id -g) -v "$PWD:/paper" -w /paper qr-latex \
  latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=build main.tex >/dev/null
cp build/main.pdf "$PDF"
echo "$PDF"
