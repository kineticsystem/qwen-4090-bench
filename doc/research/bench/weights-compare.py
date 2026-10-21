#!/usr/bin/env python3
"""Mean NLL per token of the three weight files on the same scored positions:
chunks 1-3 of 64K tokens, last 32K positions of each (chunk 0 is left out because
NInfer's first window scores all of its positions, not only the last half).

Inputs, all written by bench/weights-compare.sh:
  results/ppl-llama-q8q8-full.txt         llama-perplexity running PPL after each chunk
  results/tqkld/q8.nll.f32                azllm per-position NLL (int8 prefill, the default)
  results/tqkld/q8-fp16prefill.nll.f32    azllm per-position NLL (FP16 prefill)
  results/ppl-ninfer-int8-64k/**/report.json   NInfer per-window NLL
"""
import glob, json, math, re, sys
import numpy as np

L = 65536
out = {}

# llama.cpp: [k]P_k is the running perplexity after k chunks, so chunk k's mean NLL is
# k*ln(P_k) - (k-1)*ln(P_{k-1}).
txt = open("results/ppl-llama-q8q8-full.txt").read()
run = [float(x) for x in re.findall(r"\[\d+\]([0-9.]+)", txt)]
nll = [k * math.log(p) - (k - 1) * math.log(run[k - 2]) if k > 1 else math.log(p)
       for k, p in enumerate(run, 1)]
out["llama.cpp UD-Q4_K_XL (q8_0 KV)"] = (nll, None)

# azllm: NaN outside the scored positions.
for name, f in [("azllm TQ_L (q8 KV, int8 prefill)", "results/tqkld/q8.nll.f32"),
                ("azllm TQ_L (q8 KV, FP16 prefill)", "results/tqkld/q8-fp16prefill.nll.f32")]:
    try:
        a = np.fromfile(f, np.float32).reshape(-1, L - 1)
        out[name] = ([float(np.nanmean(r)) for r in a], None)
    except FileNotFoundError:
        pass

# NInfer: windows start at 0, 32K, 64K, ...; the window starting at c*64K scores
# [c*64K+32K, (c+1)*64K), the same positions as llama.cpp's chunk c (for c >= 1).
rep = glob.glob("results/ppl-ninfer-int8-64k/**/report.json", recursive=True)
if rep:
    r = json.load(open(rep[0]))
    wins = r["streams"][0]["windows"]
    nll = []
    for c in range(4):  # the window that scores exactly [c*L + L/2, (c+1)*L)
        w = [x for x in wins if x["target_begin"] == c * L + L // 2 and x["target_end"] == (c + 1) * L]
        nll.append(w[0]["mean_nll"] if w else float("nan"))
    out["NInfer groupwise (int8 KV)"] = (nll, None)

print(f"{'weights':38s} {'chunk1':>8s} {'chunk2':>8s} {'chunk3':>8s} {'mean 1-3':>9s} {'PPL':>7s}")
for name, (nll, _) in out.items():
    c = nll[1:4]
    m = sum(c) / len(c)
    print(f"{name:38s} " + " ".join(f"{x:8.4f}" for x in c) + f" {m:9.4f} {math.exp(m):7.4f}")
