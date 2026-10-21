#!/usr/bin/env python3
"""Accuracy check for any OpenAI-compatible chat server: GSM8K (first N) and
HumanEval (pass@1), greedy, thinking off. Runs the generated code in a
subprocess with a timeout (inside the throw-away container)."""
import argparse, gzip, json, re, subprocess, sys, tempfile, time, requests
from concurrent.futures import ThreadPoolExecutor

def chat(a, prompt, max_tokens):
    body = {"model": a.model, "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens, "temperature": 0.0, "presence_penalty": 0.0}
    if a.no_think == "kwargs": body["chat_template_kwargs"] = {"enable_thinking": False}
    elif a.no_think == "top": body["enable_thinking"] = False
    r = requests.post(a.url + "/v1/chat/completions", json=body, timeout=1800)
    r.raise_for_status()
    j = r.json()
    return j["choices"][0]["message"].get("content") or "", j.get("usage", {}).get("completion_tokens", 0)

def num(s):
    s = s.replace(",", "").replace("$", "").strip().rstrip(".")
    try: return float(s)
    except ValueError: return None

def gsm8k(a):
    rows = [json.loads(l) for l in open(a.data + "/gsm8k_test.jsonl")][:a.n_gsm]
    ok = 0; toks = 0; out = []
    for i, r in enumerate(rows):
        txt, n = chat(a, r["question"] + "\nSolve it step by step, then give the final numeric "
                      "answer on the last line as: #### <number>", 1024)
        toks += n
        gold = num(r["answer"].split("####")[-1])
        m = re.findall(r"####\s*\$?(-?[\d,]*\.?\d+)", txt) or re.findall(r"(-?[\d,]*\.?\d+)", txt)
        pred = num(m[-1]) if m else None
        good = pred is not None and abs(pred - gold) < 1e-6
        ok += good; out.append({"i": i, "ok": good, "pred": pred, "gold": gold})
    return ok / len(rows), toks, out

def extract_code(txt):
    blocks = re.findall(r"```(?:python|py)?\n(.*?)```", txt, re.S)
    return max(blocks, key=len) if blocks else txt

def run_test(code):
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
        f.write(code); p = f.name
    try:
        return subprocess.run([sys.executable, p], capture_output=True, timeout=20).returncode == 0
    except subprocess.TimeoutExpired:
        return False

def humaneval(a):
    rows = [json.loads(l) for l in gzip.open(a.data + "/HumanEval.jsonl.gz", "rt")][:a.n_he]
    toks = 0; progs = []
    for r in rows:
        txt, n = chat(a, "Complete the following Python function. Return the complete function "
                      "(with the imports it needs) in a single ```python code block.\n\n```python\n"
                      + r["prompt"] + "```", 1024)
        toks += n
        code = extract_code(txt)
        if f"def {r['entry_point']}" not in code: code = r["prompt"] + code
        # The prompt's imports and helpers, in case the answer left them out.
        header = "\n".join(l for l in r["prompt"].splitlines() if l.startswith(("import", "from")))
        progs.append(header + "\n" + code + "\n\n" + r["test"] + f"\ncheck({r['entry_point']})\n")
    with ThreadPoolExecutor(8) as ex: res = list(ex.map(run_test, progs))
    return sum(res) / len(rows), toks, [{"i": i, "ok": ok} for i, ok in enumerate(res)]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8090")
    ap.add_argument("--model", default="qwen")
    ap.add_argument("--label", required=True)
    ap.add_argument("--no-think", choices=["kwargs", "top"], default="kwargs")
    ap.add_argument("--n-gsm", type=int, default=250)
    ap.add_argument("--n-he", type=int, default=164)
    ap.add_argument("--data", default="/work/datasets")
    ap.add_argument("--out", default="/work/results/accuracy.jsonl")
    a = ap.parse_args()
    t0 = time.time()
    g, gt, gd = gsm8k(a)
    print(f"{a.label}: GSM8K {g*100:.1f}% ({a.n_gsm})", flush=True)
    h, ht, hd = humaneval(a)
    print(f"{a.label}: HumanEval {h*100:.1f}% ({a.n_he})  [{time.time()-t0:.0f}s]", flush=True)
    with open(a.out, "a") as f:
        f.write(json.dumps({"label": a.label, "gsm8k": g, "humaneval": h, "gsm_tokens": gt,
                            "he_tokens": ht, "seconds": time.time() - t0,
                            "gsm_detail": gd, "he_detail": hd}) + "\n")

if __name__ == "__main__":
    main()
