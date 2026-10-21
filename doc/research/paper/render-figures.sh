#!/bin/bash
# Render each figure of the paper to an SVG in ../images, for REPORT.md.
cd "$(dirname "$0")/.."
mkdir -p images paper/build-fig
for f in paper/figures/*.tex; do
  name=$(basename $f .tex); [ $name = standalone ] && continue
  docker run --rm -u $(id -u):$(id -g) -v $PWD:/work -w /work/paper qr-latex bash -c \
    "pdflatex -interaction=nonstopmode -jobname=$name -output-directory=build-fig '\def\fig{$name}\input{figures/standalone}' >/dev/null \
     && pdftocairo -svg build-fig/$name.pdf /work/images/$name.svg" \
    && echo "images/$name.svg" || echo "FAILED $name"
done
