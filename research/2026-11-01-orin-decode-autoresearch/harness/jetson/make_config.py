#!/usr/bin/env python3
"""Experiment config = the installed IQ3_S 256K config with exe, log and flag/env overrides applied in order.
usage: make_config.py BASE.json EXE OUT.json [OVERRIDES.json ...]
OVERRIDES: {"args": {"--flag": "value" | true (bare flag) | null (remove)}, "env": {"NAME": "value"}}
Fixed by the experiment design (refused if overridden): --max-context, --kv, --pack, --native, --ple-gguf."""
import json
import sys
from pathlib import Path

FIXED = {"--max-context", "--kv", "--pack", "--native", "--ple-gguf"}
base, exe, out = sys.argv[1:4]
cfg = json.loads(Path(base).read_text())
args = cfg["args"]
pairs = []                                   # [flag, value-or-None]
i = 0
while i < len(args):
    if i + 1 < len(args) and not args[i + 1].startswith("--"):
        pairs.append([args[i], args[i + 1]]); i += 2
    else:
        pairs.append([args[i], None]); i += 1
env = dict(cfg.get("env", {}))
for path in sys.argv[4:]:
    ovr = json.loads(Path(path).read_text()) if Path(path).exists() else {}
    for flag, value in (ovr.get("args") or {}).items():
        if not flag.startswith("--"):
            sys.exit(f"bad flag {flag!r}")
        if flag in FIXED:
            sys.exit(f"{flag} is fixed by the experiment design")
        pairs = [p for p in pairs if p[0] != flag]
        if value is True:
            pairs.append([flag, None])
        elif value is not None:
            pairs.append([flag, str(value)])
    env.update({k: str(v) for k, v in (ovr.get("env") or {}).items()})
cfg["args"] = [x for p in pairs for x in p if x is not None]
cfg["exe"] = exe
cfg["log"] = str(Path(out).parent / "engine.log")
cfg["port"] = 18090
cfg["env"] = env
Path(out).write_text(json.dumps(cfg, indent=1) + "\n")
print(" ".join(cfg["args"]), " ENV:", env)
