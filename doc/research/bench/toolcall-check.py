#!/usr/bin/env python3
"""Send a request with one tool to the server on port 8084; print whether the model called it."""
import json, requests
body = {"model": "Qwen3.8-27B", "max_tokens": 2000, "temperature": 0,
        "chat_template_kwargs": {"enable_thinking": False},
        "messages": [{"role": "user", "content": "What is the weather in Paris right now? Use the tool."}],
        "tools": [{"type": "function", "function": {"name": "get_weather", "description": "Current weather of a city",
                   "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}}]}
r = requests.post("http://127.0.0.1:8084/v1/chat/completions", json=body, timeout=600).json()
m = r["choices"][0]["message"]; calls = m.get("tool_calls") or []
print("finish:", r["choices"][0]["finish_reason"], "| calls:",
      [(c["function"]["name"], c["function"]["arguments"]) for c in calls] or m.get("content", "")[:120])
