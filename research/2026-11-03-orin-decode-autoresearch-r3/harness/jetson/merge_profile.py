#!/usr/bin/env python3
"""Round 3 expert-cache profile: the review-learned warm profile's ranking interleaved one-for-one with the ranking of
held-out routing traces (code review, prose, repetition; most frequent first), so the experts each kind of text uses
most come first and the GPU cache (its top ~19,068 of 24,576 pairs) covers all three. Placement only: lossless.
usage: merge_profile.py BASE.bin OUT.bin TRACE [TRACE ...]   (also prints coverage numbers)"""
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, "/home/<user>/strata/strata-ninfer-jetson-orin/tools")
from make_profile import N_EXPERT, N_LAYER, read_profile, read_trace, write_profile  # noqa: E402

base, out, traces = sys.argv[1], sys.argv[2], sys.argv[3:]
base_pairs = [(int(l), int(e)) for l, e in read_profile(base)]
freq = defaultdict(int)
for t in traces:
    for p, c in read_trace(t).items():
        freq[p] += c
trace_pairs = [p for p, _ in sorted(freq.items(), key=lambda kv: (-kv[1], kv[0]))]
ranked, seen = [], set()
for i in range(max(len(base_pairs), len(trace_pairs))):
    for src in (base_pairs, trace_pairs):
        if i < len(src) and src[i] not in seen:
            seen.add(src[i]); ranked.append(src[i])
for layer in range(N_LAYER):
    for e in range(N_EXPERT):
        if (layer, e) not in seen:
            seen.add((layer, e)); ranked.append((layer, e))
assert len(ranked) == N_LAYER * N_EXPERT
write_profile(out, ranked)
K = 19068
total = sum(freq.values())
cov = lambda pairs: sum(freq[p] for p in pairs[:K]) / total
print(f"{len(traces)} traces, {total} routed picks, {len(freq)} distinct pairs")
print(f"trace picks covered by the top {K}: old profile {cov(base_pairs):.3f}, merged {cov(ranked):.3f}, "
      f"traces alone {cov(trace_pairs):.3f}")
print(f"old profile's top {K} kept in the merged top {K}: {len(set(base_pairs[:K]) & set(ranked[:K])) / K:.3f}")
old_top, new_top = set(base_pairs[:K]), set(ranked[:K])
for t in traces:
    f = read_trace(t); n = sum(f.values())
    old = sum(c for p, c in f.items() if p in old_top) / n
    new = sum(c for p, c in f.items() if p in new_top) / n
    print(f"  {Path(t).parent.name}: picks covered, old {old:.3f} -> merged {new:.3f}")
