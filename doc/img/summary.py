#!/usr/bin/env python3
"""Draw doc/img/summary.svg, the image at the top of the README: decode speed and context
of each model, from the table of The Results and the Bonsai measurements.

Usage: python3 doc/img/summary.py   (needs matplotlib)
The text is drawn as outlines, so the image looks the same whatever fonts the reader has.
"""
from pathlib import Path

import matplotlib
matplotlib.use("svg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

# name, engine, tok/s, context, kind: best (Qwen3.8, fastest engine), bonsai, or other
MODELS = [
    ("bonsai-ninfer", "NInfer fork, Bonsai 2 27B", 264.8, "256K", "bonsai"),
    ("azllm-228k", "azllm", 228.8, "228K", "best"),
    ("azllm", "azllm", 228.6, "148K", "best"),
    ("ninfer-fast", "NInfer", 166.0, "76K", "other"),
    ("ninfer-long", "NInfer", 139.0, "172K", "other"),
    ("ninfer-precise", "NInfer", 137.4, "116K", "other"),
    ("openjet", "OpenJet", 135.9, "64K", "other"),
    ("baseline", "llama.cpp", 89.6, "128K", "other"),
]
COLOR = {"best": "#2979d6", "bonsai": "#2e9e6b", "other": "#b9b8b0"}
BG, GRID, AXIS, INK, SOFT, FAINT = "#fcfcfb", "#e1e0d9", "#c3c2b7", "#111111", "#555555", "#888888"
XMAX = 300

n = len(MODELS)
fig = plt.figure(figsize=(12, 4.0 + 1.05 * n), facecolor=BG)
H = fig.get_figheight()
ax = fig.add_axes([0.335, 1.25 / H, 0.54, (1.05 * n) / H], facecolor=BG)

fig.text(0.06, 1 - 0.55 / H, "Qwen3.8-27B on one RTX 4090", fontsize=34, weight="bold",
         color=INK, va="top")
fig.text(0.06, 1 - 1.35 / H, "Four inference engines and a fork of NInfer, one 24 GB card.\n"
         "In green, Bonsai 2 27B, the ternary build of Qwen3.8-27B.",
         fontsize=17, color=SOFT, va="top", linespacing=1.5)

for x in range(0, XMAX + 1, 60):
    ax.axvline(x, color=AXIS if x == 0 else GRID, lw=1, zorder=0)
for i, (name, engine, tps, ctx, kind) in enumerate(MODELS):
    y = n - 1 - i
    ax.add_patch(FancyBboxPatch((0, y - 0.21), tps, 0.42, boxstyle="round,pad=0,rounding_size=1.6",
                                mutation_aspect=0.12, fc=COLOR[kind], ec="none", zorder=2))
    bold = "bold" if kind != "other" else "normal"
    ax.text(-8, y + 0.12, name, ha="right", va="center", fontsize=19, weight=bold, color=INK)
    ax.text(-8, y - 0.17, engine, ha="right", va="center", fontsize=14, color=SOFT)
    ax.text(tps + 5, y + 0.12, f"{tps:.1f} tok/s", ha="left", va="center", fontsize=19,
            weight=bold, color=INK)
    ax.text(tps + 5, y - 0.17, f"{ctx} context", ha="left", va="center", fontsize=14, color=SOFT)

ax.set_xlim(0, XMAX)
ax.set_ylim(-0.6, n - 0.4)
ax.set_yticks([])
ax.set_xticks(range(0, XMAX + 1, 60))
ax.tick_params(axis="x", length=0, labelsize=14, labelcolor=FAINT, pad=8)
ax.set_xlabel("tokens per second, short prompts", fontsize=14, color=FAINT, loc="right", labelpad=10)
for s in ax.spines.values():
    s.set_visible(False)

out = Path(__file__).with_name("summary.svg")
plt.rcParams["svg.hashsalt"] = "summary"
fig.savefig(out, facecolor=BG, metadata={"Date": None})
print(f"wrote {out}")
