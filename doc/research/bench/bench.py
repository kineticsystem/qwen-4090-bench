#!/usr/bin/env python3
"""Decode-speed benchmark for any OpenAI-compatible chat server.

Streams each prompt, and measures on the client side:
  decode tok/s = (completion_tokens - 1) / (time of last token - time of first token)
so that every engine is measured the same way, whatever it reports itself.
"""
import argparse, json, statistics, sys, time, requests

NO_THINK = "kwargs"  # how to turn thinking off: llama.cpp kwargs, or a top-level field

PROMPTS = {
    "code": "Write a Python implementation of an LRU cache class with get/put in O(1), "
            "using a dict and a doubly linked list. Include type hints and docstrings.",
    "code2": "Write a C++17 function that parses a CSV line with quoted fields (RFC 4180) "
             "into a std::vector<std::string>, then a few unit tests with assert.",
    "prose": "Write a short story (about 400 words) about a lighthouse keeper who "
             "discovers the light has been signalling to something under the sea.",
    "explain": "Explain how a transformer's attention mechanism works to a software "
               "engineer who knows linear algebra but not machine learning.",
    "math": "A train leaves city A at 9:00 at 80 km/h. Another leaves city B, 340 km away, "
            "at 10:00 towards A at 100 km/h. At what time do they meet and how far from A? "
            "Show your reasoning.",
    "list": "List 20 countries in Europe with their capital and approximate population, "
            "as a markdown table.",
}

def run(url, model, prompt, max_tokens, sampling, think):
    body = {"model": model, "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens, "stream": True,
            "stream_options": {"include_usage": True}, **sampling}
    if not think:
        if NO_THINK == "kwargs": body["chat_template_kwargs"] = {"enable_thinking": False}
        else: body["enable_thinking"] = False
    else:  # the user's reasoning effort, as the baseline server sets it
        if NO_THINK == "kwargs": body["chat_template_kwargs"] = {"reasoning_effort": "medium"}
        else: body["reasoning_effort"] = "medium"
    t0 = time.perf_counter(); first = last = None; n_chunks = 0; usage = None; text = []
    with requests.post(url + "/v1/chat/completions", json=body, stream=True, timeout=1800) as r:
        r.raise_for_status()
        for line in r.iter_lines():
            if not line.startswith(b"data: "): continue
            data = line[6:]
            if data == b"[DONE]": break
            j = json.loads(data)
            if j.get("usage"): usage = j["usage"]
            for c in j.get("choices", []):
                d = c.get("delta", {})
                piece = (d.get("content") or "") + (d.get("reasoning_content") or "") + (d.get("reasoning") or "")
                if piece:
                    now = time.perf_counter()
                    if first is None: first = now
                    last = now; n_chunks += 1; text.append(piece)
    n = usage["completion_tokens"] if usage else n_chunks
    return {"tokens": n, "ttft": first - t0, "decode_tps": (n - 1) / (last - first) if last > first else 0,
            "text": "".join(text)}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8090")
    ap.add_argument("--model", default="qwen")
    ap.add_argument("--label", required=True)
    ap.add_argument("--max-tokens", type=int, default=1024)
    ap.add_argument("--greedy", action="store_true", help="temperature 0 instead of the recommended sampling")
    ap.add_argument("--think", action="store_true", help="leave thinking on")
    ap.add_argument("--reps", type=int, default=1)
    ap.add_argument("--out", default="/work/results/bench.jsonl")
    ap.add_argument("--long", type=int, default=0,
                    help="instead of the short prompts, ask questions about N characters of source code")
    ap.add_argument("--no-think", choices=["kwargs", "top"], default="kwargs")
    a = ap.parse_args()
    global NO_THINK; NO_THINK = a.no_think
    sampling = {"temperature": 0.0, "presence_penalty": 0.0} if a.greedy else \
        {"temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0.0, "presence_penalty": 0.0, "seed": 1234}
    prompts = PROMPTS
    if a.long:
        import glob
        src = "".join(open(f).read() for f in sorted(glob.glob(
            "/work/src/llama-cpp-turboquant/ggml/src/ggml-cuda/*.cu")))[:a.long]
        prompts = {f"long-{k}": "```cpp\n" + src + "\n```\n\n" + q for k, q in {
            "summary": "Summarize what each kernel in the code above does, as a bullet list.",
            "review": "Review the code above: list the five most serious potential bugs or "
                      "performance problems, each with the fix as a code snippet.",
            "tests": "Write a C++ test program that checks the first kernel above against a "
                     "simple CPU reference implementation."}.items()}
    run(a.url, a.model, "Say hello.", 16, sampling, False)  # warm-up
    rows = []
    for rep in range(a.reps):
        for name, p in prompts.items():
            r = run(a.url, a.model, p, a.max_tokens, sampling, a.think)
            print(f"{a.label:30s} {name:8s} tokens={r['tokens']:5d} ttft={r['ttft']:.2f}s "
                  f"decode={r['decode_tps']:6.1f} tok/s", flush=True)
            rows.append({"label": a.label, "prompt": name, "rep": rep, "greedy": a.greedy,
                         "think": a.think, **r})
    tps = [r["decode_tps"] for r in rows]
    summary = {"label": a.label, "greedy": a.greedy, "think": a.think,
               "mean_tps": statistics.mean(tps), "median_tps": statistics.median(tps),
               "per_prompt": {r["prompt"]: round(r["decode_tps"], 1) for r in rows}}
    print(f"== {a.label}: mean {summary['mean_tps']:.1f} tok/s, median {summary['median_tps']:.1f} tok/s")
    with open(a.out, "a") as f:
        for r in rows: f.write(json.dumps(r) + "\n")
    with open(a.out.replace(".jsonl", "_summary.jsonl"), "a") as f:
        f.write(json.dumps(summary) + "\n")

if __name__ == "__main__":
    main()
