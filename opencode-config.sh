#!/bin/bash
# Add the models of the running qwen-4090-bench container to opencode, as the provider
# "qwen-4090-bench": reads the list from llama-swap's /v1/models (names and context sizes
# included, from scripts/llama-swap.yaml) and writes it into opencode's configuration,
# after a backup. Run it again after changing scripts/llama-swap.yaml.
#
# Usage: ./opencode-config.sh [--default MODEL] [--config FILE]
#   --default  also make qwen-4090-bench/MODEL opencode's default model, e.g. azllm
#   --config   opencode configuration (default ~/.config/opencode/opencode.json)
set -euo pipefail
PORT=${PORT:-8085}
config=$HOME/.config/opencode/opencode.json default=""
while [ $# -gt 0 ]; do case "$1" in
  --default) default=$2; shift 2 ;;
  --config) config=$2; shift 2 ;;
  *) echo "unknown option $1" >&2; exit 1 ;;
esac; done

models=$(curl -sf http://127.0.0.1:$PORT/v1/models) || {
  echo "no answer on http://127.0.0.1:$PORT/v1/models: start the container with ./docker/dock.sh start" >&2
  exit 1
}
mkdir -p "$(dirname "$config")"
[ -f "$config" ] && cp "$config" "$config.bak-$(date +%Y%m%d-%H%M%S)"

MODELS_JSON=$models python3 - "$config" "$PORT" "$default" <<'EOF'
import json, os, sys
config, port, default = sys.argv[1], sys.argv[2], sys.argv[3]

def find(d, key):
    """The first value of key in the nested dictionaries of d, wherever llama-swap puts it."""
    if isinstance(d, dict):
        if key in d:
            return d[key]
        for v in d.values():
            r = find(v, key)
            if r is not None:
                return r
    return None

models = {}
for m in json.loads(os.environ["MODELS_JSON"])["data"]:
    context = find(m, "context")
    if context is None:
        print(f"skipping {m['id']}: no context size in its metadata")
        continue
    models[m["id"]] = {"name": m.get("name") or m["id"], "tool_call": True,
                       "limit": {"context": int(context), "output": int(find(m, "output") or 16384)}}

c = json.load(open(config)) if os.path.exists(config) else {"$schema": "https://opencode.ai/config.json"}
c.setdefault("provider", {})["qwen-4090-bench"] = {
    "name": "Qwen3.8-27B on RTX 4090 (qwen-4090-bench)",
    "npm": "@ai-sdk/openai-compatible",
    # A model that is not loaded takes 1 to 2 minutes to start: wait up to 10 minutes.
    "options": {"baseURL": f"http://127.0.0.1:{port}/v1", "apiKey": "local",
                "includeUsage": True, "timeout": 600000},
    "models": models,
}
if default:
    if default not in models:
        sys.exit(f"--default {default}: not one of {', '.join(models)}")
    c["model"] = c["small_model"] = f"qwen-4090-bench/{default}"
json.dump(c, open(config, "w"), indent=2)
print(f"{config}: provider qwen-4090-bench with {len(models)} models")
for k, v in models.items():
    print(f"  qwen-4090-bench/{k:16s} {v['limit']['context']:>7,d} tokens  {v['name']}")
if default:
    print(f"default model: qwen-4090-bench/{default}")
EOF
