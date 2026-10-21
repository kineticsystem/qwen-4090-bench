#!/usr/bin/env python3
"""Long-context coding precision test for any OpenAI-compatible chat server.

Fills the context with C/C++ source of llama.cpp (about --tokens prompt tokens),
then asks questions spread over the whole depth: "copy the first 8 lines of the
body of function F in file P". Exact recall of code deep in the context is where
a lossy KV cache hurts first, so this is our KV-precision test for coding.

The code sits in a first user message, so that every question shares the same
prefix and engines with prefix reuse prefill it only once.
"""
import argparse, difflib, glob, json, re, time, requests

ROOT = "/work/src/llama-cpp-turboquant"
GLOBS = ["src/*.cpp", "src/*.h", "common/*.cpp", "common/*.h", "ggml/src/*.c", "ggml/src/*.cpp",
         "ggml/src/ggml-cuda/*.cu", "ggml/src/ggml-cuda/*.cuh", "ggml/src/ggml-cpu/*.c",
         "ggml/src/ggml-cpu/*.cpp", "tools/server/*.cpp", "tools/*/*.cpp", "examples/*/*.cpp"]
DEF = re.compile(r"^(?:static\s+|inline\s+)*[A-Za-z_][\w:<>\*&\s,]*?\b([A-Za-z_]\w*)\s*\([^;{}]*\)\s*(?:const\s*)?\{\s*$")
N_LINES = 8

def corpus(max_chars):
    parts, n = [], 0
    for g in GLOBS:
        for f in sorted(glob.glob(f"{ROOT}/{g}")):
            text = open(f, errors="replace").read()
            parts.append((f[len(ROOT) + 1:], text)); n += len(text)
            if n > max_chars: return parts
    return parts

def render(parts):
    return "".join(f"\n// ===== File: {p} =====\n{t}" for p, t in parts)

def questions(parts, n_q):
    """Function definitions at n_q evenly spaced depths, with a unique signature
    line and N_LINES non-trivial body lines."""
    full = render(parts)
    cands = []; offset = 0  # (depth, file, name, body) of functions defined once in their file
    for p, t in parts:
        offset += len(f"\n// ===== File: {p} =====\n")
        lines = t.split("\n"); pos = offset
        for i, l in enumerate(lines):
            m = DEF.match(l)
            body = lines[i + 1:i + 1 + N_LINES]
            if m and len(body) == N_LINES and all(b.strip() and b.strip() != "}" for b in body[:3]) \
                    and full.count(l) == 1 and not any(b.startswith("}") for b in body) \
                    and sum(1 for x in lines if (d := DEF.match(x)) and d.group(1) == m.group(1)) == 1:
                cands.append((pos / len(full), p, m.group(1), body))
            pos += len(l) + 1
        offset += len(t)
    out = []
    for k in range(n_q):
        want = (k + 0.5) / n_q
        free = [c for c in cands if c not in out]
        out.append(min(free, key=lambda c: abs(c[0] - want)))
    return out

def chat(a, code, q, max_tokens):
    msgs = [{"role": "user", "content": "Here is the source code of a project.\n" + code +
             "\n\nI will ask you questions about it."},
            {"role": "assistant", "content": "Understood. Ask your questions."},
            {"role": "user", "content": q}]
    body = {"model": a.model, "messages": msgs, "max_tokens": max_tokens, "temperature": 0.0,
            "presence_penalty": 0.0, "stream": True, "stream_options": {"include_usage": True}}
    if a.no_think == "kwargs": body["chat_template_kwargs"] = {"enable_thinking": False}
    else: body["enable_thinking"] = False
    t0 = time.perf_counter(); first = last = None; text = []; usage = None
    with requests.post(a.url + "/v1/chat/completions", json=body, stream=True, timeout=3600) as r:
        if r.status_code != 200: raise RuntimeError(f"HTTP {r.status_code}: {r.text[:300]}")
        for line in r.iter_lines():
            if not line.startswith(b"data: ") or line == b"data: [DONE]": continue
            j = json.loads(line[6:])
            if "error" in j: raise RuntimeError(str(j["error"])[:300])
            if j.get("usage"): usage = j["usage"]
            for c in j.get("choices", []):
                piece = c.get("delta", {}).get("content") or ""
                if piece:
                    now = time.perf_counter(); first = first or now; last = now; text.append(piece)
    n = (usage or {}).get("completion_tokens", len(text))
    return "".join(text), (usage or {}).get("prompt_tokens", 0), (first or t0) - t0, \
        (n - 1) / (last - first) if first and last > first else 0.0

def score(answer, truth):
    blocks = re.findall(r"```[\w+]*\n(.*?)```", answer, re.S)
    got = [l.strip() for l in (blocks[0] if blocks else answer).strip("\n").split("\n") if l.strip()]
    want = [l.strip() for l in truth if l.strip()]
    hits = sum(1 for i, w in enumerate(want) if i < len(got) and got[i] == w)
    return hits / len(want), difflib.SequenceMatcher(None, got[:len(want)], want).ratio()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8090")
    ap.add_argument("--model", default="qwen")
    ap.add_argument("--label", required=True)
    ap.add_argument("--tokens", type=int, required=True, help="target prompt length in tokens")
    ap.add_argument("--n-questions", type=int, default=8)
    ap.add_argument("--lines", type=int, default=8, help="body lines to copy per question")
    ap.add_argument("--no-think", choices=["kwargs", "top"], default="kwargs")
    ap.add_argument("--out", default="/work/results/longctx.jsonl")
    a = ap.parse_args()
    global N_LINES; N_LINES = a.lines
    chars = int(a.tokens * 3.2)
    for attempt in range(4):  # fit the prompt to the target length
        parts = corpus(chars)
        code = render(parts)[:chars]
        _, n_prompt, ttft, _ = chat(a, code, "Reply with OK.", 1)
        print(f"{a.label}: {chars} chars -> {n_prompt} prompt tokens, prefill {ttft:.1f}s", flush=True)
        if n_prompt <= a.tokens and n_prompt > a.tokens * 0.97: break
        chars = int(chars * (a.tokens * 0.985) / n_prompt)
    # The questions come from the code exactly as it was sent.
    file_parts = []
    for chunk in code.split("\n// ===== File: ")[1:]:
        p, _, t = chunk.partition(" =====\n"); file_parts.append((p, t))
    qs = questions(file_parts, a.n_questions)
    rows = []
    for depth, path, name, body in qs:
        q = (f"In the file `{path}`, find the definition of the function `{name}`. Copy the first "
             f"{N_LINES} lines of its body exactly as they appear, starting with the line after the "
             f"opening brace. Reply with one code block only.")
        ans, n_prompt, ttft, tps = chat(a, code, q, 60 * N_LINES)
        line_acc, sim = score(ans, body)
        rows.append({"depth": round(depth, 3), "file": path, "function": name, "answer": ans,
                     "truth": "\n".join(body), "line_acc": line_acc,
                     "similarity": round(sim, 3), "ttft": round(ttft, 1), "decode_tps": round(tps, 1)})
        print(f"  depth {depth:4.0%} {name:32s} lines {line_acc:4.0%} sim {sim:.2f} "
              f"ttft {ttft:6.1f}s decode {tps:5.1f} tok/s", flush=True)
    exact = sum(r["line_acc"] == 1.0 for r in rows) / len(rows)
    line = sum(r["line_acc"] for r in rows) / len(rows)
    tps = sum(r["decode_tps"] for r in rows) / len(rows)
    print(f"== {a.label} @ {n_prompt} tokens: exact {exact:.0%}, lines {line:.0%}, decode {tps:.1f} tok/s")
    with open(a.out, "a") as f:
        f.write(json.dumps({"label": a.label, "lines": N_LINES, "prompt_tokens": n_prompt, "exact": exact,
                            "line_acc": line, "decode_tps": tps, "rows": rows}) + "\n")

if __name__ == "__main__":
    main()
