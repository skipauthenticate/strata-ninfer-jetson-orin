#!/usr/bin/env python3
"""One run folder -> result JSON: status, decode/prefill/TTFT medians, memory floor, hit rate, outputs, needles."""
import json
import re
import statistics
import sys
from pathlib import Path

o = Path(sys.argv[1])
res = {"exp": o.name, "status": "no_result"}
if (o / "exe.sha256").exists():
    res["exe_sha256"] = (o / "exe.sha256").read_text().strip()
sup = o / "supervisor" / "result.json"
if sup.exists():
    s = json.loads(sup.read_text())
    res["supervisor"] = s.get("status")
    res["min_avail_gib"] = round(s.get("minimum_admission_available_bytes", 0) / 2**30, 2)
    if s.get("status") == "pressure_abort":
        res["status"] = "pressure_abort"
rows_path = o / "speed" / "results.json"
if rows_path.exists():
    rows = [r for r in json.loads(rows_path.read_text()) if r["label"] != "warmup"]
    if len(rows) == 3:
        dec = [r["engine"]["engine_generated"] / (r["engine"]["decode_ms"] / 1000) for r in rows]
        pre = [(r["engine"]["prompt_tokens"] - (r["engine"].get("reused") or 0)) / (r["engine"]["prompt_ms"] / 1000) for r in rows]
        res.update(status="ok" if res["status"] == "no_result" else res["status"],
                   decode_med=round(statistics.median(dec), 2), decode_min=round(min(dec), 2), decode_max=round(max(dec), 2),
                   decode_runs=[round(x, 2) for x in dec],
                   prefill_med=round(statistics.median(pre), 1),
                   ttft_med=round(statistics.median(r["client_ttft_s"] for r in rows), 2),
                   generated=[r["engine"]["engine_generated"] for r in rows],
                   texts=[r["text"] for r in rows])
for w in ("prose", "repetition"):   # round 3 workloads
    wp = o / f"speed-{w}" / "results.json"
    if wp.exists():
        wr = [r for r in json.loads(wp.read_text()) if r["label"] != "warmup"]
        if len(wr) == 3:
            wd = [r["engine"]["engine_generated"] / (r["engine"]["decode_ms"] / 1000) for r in wr]
            res.setdefault("workloads", {})[w] = {"decode_med": round(statistics.median(wd), 2),
                                                  "decode_runs": [round(x, 2) for x in wd],
                                                  "generated": [r["engine"]["engine_generated"] for r in wr],
                                                  "texts": [r["text"] for r in wr]}
wl = res.get("workloads", {})
if "prose" in wl and "repetition" in wl:
    res["prose_med"], res["rep_med"] = wl["prose"]["decode_med"], wl["repetition"]["decode_med"]
    res["pr_mean"] = round((res["prose_med"] + res["rep_med"]) / 2, 2)
if res.get("status") == "ok" and (o / "benchmark-prose.txt").exists() and "pr_mean" not in res:
    res["status"] = "partial"   # the run had the workloads but one did not finish: never a PASS
log = o / "engine.log"
if log.exists():
    t = log.read_text(errors="replace")
    hits = [float(x) for x in re.findall(r"decode expert cache hit rate: ([0-9.]+)%", t)]
    res["hit_rate_last"] = hits[3] if len(hits) > 3 else (hits[-1] if hits else None)   # review's last request
    # one line a request: review warmup + 3, prose warmup + 3, repetition warmup + 3 (then needles)
    for name, sl in (("hit_review", slice(1, 4)), ("hit_prose", slice(5, 8)), ("hit_rep", slice(9, 12))):
        if len(hits[sl]) == 3:
            res[name] = round(statistics.median(hits[sl]), 1)
    slots = re.findall(r"expert cache (\d+) slots, ([0-9.]+) GiB", t)
    res["cache_slots"] = int(slots[-1][0]) if slots else None
    res["engine_errors"] = [l for l in t.splitlines() if re.search(r"error|fail|abort|out of memory|reset|xid|fault", l, re.I)][:5]
n = o / "needles.json"
if n.exists():
    nd = json.loads(n.read_text())
    res["needles"] = f"{sum(x.get('found') is True for x in nd)}/{len(nd)}"
print(json.dumps(res, indent=1))
