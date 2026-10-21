#!/usr/bin/env python3
"""Write the chat template embedded in a GGUF file, reading only the file's header.

Usage: gguf-template.py <url> <output.jinja>

The metadata of a GGUF file comes before its tensors, so the first megabytes are enough:
the file is fetched with an HTTP range request, 40 MB at most.
"""
import struct, sys, urllib.request

HEAD = 40 * 1024 * 1024
SIZES = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8}  # GGUF scalar types

url, out = sys.argv[1], sys.argv[2]
req = urllib.request.Request(url, headers={"Range": f"bytes=0-{HEAD - 1}"})
b = urllib.request.urlopen(req).read()
if b[:4] != b"GGUF":
    sys.exit(f"{url} is not a GGUF file")
_, _, n_kv = struct.unpack_from("<IQQ", b, 4)
pos = 24

def string():
    global pos
    n = struct.unpack_from("<Q", b, pos)[0]
    pos += 8
    s = b[pos:pos + n]
    pos += n
    return s

def skip(t):
    """Move past a value of type t; return it when it is a string."""
    global pos
    if t == 8:
        return string()
    if t == 9:  # array: element type, count, elements
        et, n = struct.unpack_from("<IQ", b, pos)
        pos += 12
        for _ in range(n):
            skip(et)
        return None
    pos += SIZES[t]
    return None

for _ in range(n_kv):
    key = string().decode()
    t = struct.unpack_from("<I", b, pos)[0]
    pos += 4
    value = skip(t)
    if key == "tokenizer.chat_template":
        open(out, "wb").write(value)
        print(f"wrote {out}: {len(value)} bytes")
        sys.exit(0)
sys.exit("no tokenizer.chat_template in the header")
