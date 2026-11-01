#!/usr/bin/env python3
"""Output agreement of one run vs the baseline runs: per prompt, the fraction of the baseline text that the run
reproduces before its first difference (1.0 = identical), best over baselines. Also the baselines' own agreement.
usage: compare.py RESULT.json BASELINE_RESULT.json [BASELINE_RESULT.json ...]"""
import json
import sys
from itertools import combinations


def prefix_frac(a, b):
    n = 0
    for x, y in zip(a, b):
        if x != y:
            break
        n += 1
    return 1.0 if a == b else n / max(len(b), 1)


run = json.load(open(sys.argv[1]))
bases = [json.load(open(p)) for p in sys.argv[2:]]
bases = [b for b in bases if b.get("texts")]
out = {"agreement_min": None, "per_prompt": None, "baseline_self_min": None}
if run.get("texts") and bases:
    per = [max(prefix_frac(t, b["texts"][i]) for b in bases) for i, t in enumerate(run["texts"])]
    out.update(agreement_min=round(min(per), 4), per_prompt=[round(x, 4) for x in per])
if len(bases) >= 2:
    self_ = [prefix_frac(a["texts"][i], b["texts"][i]) for a, b in combinations(bases, 2) for i in range(3)]
    out["baseline_self_min"] = round(min(self_), 4)
print(json.dumps(out))
