#!/usr/bin/env python3
"""Token ids of benchmark.py's first 4,096-token prompt (chat template applied), for engine probes (--tokens-file)."""
import json
import sys
from pathlib import Path

R = Path("/home/<user>/strata/strata-ninfer-jetson-orin")
sys.path[:0] = [str(R), str(R / "tools")]
from strata_tokenizer import Tokenizer                      # noqa: E402
from serve.frontend import ChatTemplate, openai_to_messages  # noqa: E402

d = Path("/home/<user>/strata/Strata-data/packs/iq3_s/tokenizer")
vocab = json.loads((d / "vocab.json").read_text(encoding="utf-8"))
toks = [None] * len(vocab)
for t, n in vocab.items():
    toks[n] = t
tok = Tokenizer(toks, (d / "merges.txt").read_text(encoding="utf-8").splitlines(),
                json.loads((d / "token_type.json").read_text(encoding="utf-8")))
tpl = ChatTemplate(d / "chat_template.jinja")
target = int(sys.argv[1]) if len(sys.argv) > 1 else 4096
filler = "\n".join(f"def task_{i:05d}(value: int) -> int: return (value * {(i % 97) + 1} + {i}) % 100003" for i in range(12000))
ending = ("\n\nWrite a detailed explanation of the code above. Discuss deterministic integer transforms, "
          "modulo arithmetic, testing, naming, complexity, and maintainability. Write at least 600 words.")
prefix = f"Benchmark nonce: series-{target}-trial-1.\nReview this synthetic Python module:\n"


def ids(n):
    req = {"messages": [{"role": "user", "content": prefix + filler[:n] + ending}], "reasoning_effort": "none"}
    m, tools, kw = openai_to_messages(req)
    return tok.encode(tpl.render(m, tools, **kw), parse_special=True)


lo, hi = 0, len(filler)
while lo < hi:
    mid = (lo + hi + 1) // 2
    if len(ids(mid)) <= target:
        lo = mid
    else:
        hi = mid - 1
out = ids(lo)
print(",".join(map(str, out)))
print(len(out), file=sys.stderr)
