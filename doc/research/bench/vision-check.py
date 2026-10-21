#!/usr/bin/env python3
"""Ask the server on port 8084 to describe a picture; prints the answer or the error."""
import base64, requests
img = "/home/robot/repo/stepit-macro/docs/images/jstest-gtk.png"
b = base64.b64encode(open(img, "rb").read()).decode()
body = {"model": "Qwen3.8-27B", "max_tokens": 60, "temperature": 0,
        "messages": [{"role": "user", "content": [
            {"type": "text", "text": "Describe this image in one sentence."},
            {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b}}]}]}
# NInfer takes enable_thinking at the top level and rejects chat_template_kwargs;
# llama.cpp and OpenJet take chat_template_kwargs.
r = requests.post("http://127.0.0.1:8084/v1/chat/completions", timeout=600,
                  json={**body, "chat_template_kwargs": {"enable_thinking": False}})
if r.status_code == 400:
    r = requests.post("http://127.0.0.1:8084/v1/chat/completions", timeout=600,
                      json={**body, "enable_thinking": False})
print(r.json()["choices"][0]["message"]["content"][:150].replace("\n", " ") if r.ok else f"HTTP {r.status_code} {r.text[:150]}")
