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
log = o / "engine.log"
if log.exists():
    t = log.read_text(errors="replace")
    hits = re.findall(r"decode expert cache hit rate: ([0-9.]+)%", t)
    res["hit_rate_last"] = float(hits[-1]) if hits else None
    slots = re.findall(r"expert cache (\d+) slots, ([0-9.]+) GiB", t)
    res["cache_slots"] = int(slots[-1][0]) if slots else None
    res["engine_errors"] = [l for l in t.splitlines() if re.search(r"error|fail|abort|out of memory|reset|xid|fault", l, re.I)][:5]
n = o / "needles.json"
if n.exists():
    nd = json.loads(n.read_text())
    res["needles"] = f"{sum(x.get('found') is True for x in nd)}/{len(nd)}"
print(json.dumps(res, indent=1))
