#!/usr/bin/env python3
"""Token ids (chat template applied) of a held-out profiling prompt: a slice of a text file plus an instruction, cut
to at most TARGET tokens. Used to record routing traces for the round 3 expert profile on text the benchmark never
uses. usage: gen_text_tokens.py FILE START_CHAR TARGET "instruction" > out.tokens"""
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
path, start, target, instruction = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
text = Path(path).read_text(encoding="utf-8", errors="replace").replace("\r", "")[start:start + 40000]


def ids(n):
    req = {"messages": [{"role": "user", "content": text[:n] + "\n\n" + instruction}], "reasoning_effort": "none"}
    m, tools, kw = openai_to_messages(req)
    return tok.encode(tpl.render(m, tools, **kw), parse_special=True)


lo, hi = 0, len(text)
while lo < hi:
    mid = (lo + hi + 1) // 2
    if len(ids(mid)) <= target:
        lo = mid
    else:
        hi = mid - 1
out = ids(lo)
print(",".join(map(str, out)))
print(len(out), file=sys.stderr)
