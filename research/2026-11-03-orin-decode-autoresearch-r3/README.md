# Decode autoresearch, round 3, on a Jetson AGX Orin 64 GB, 2026-11-03

A third unattended loop, two days after [round 2](../2026-11-01-orin-decode-autoresearch-r2/README.md). Same board
(JetPack 7, CUDA 13.2), same model, same rules: lossless only, a fixed 262,144-token context, and a change is kept
only if the output text stays identical. New in this round: **three workloads** on every run instead of one, a
queue on the board so builds and measurements run without the laptop, and a literature pass over other engines
before the loop started. The loop was resumed for 4.5 hours on 2026-11-04 to win back time lost to a usage limit;
that [continuation](#continuation-2026-11-04-1355-1825-pst) moved the miss pool onto 9 of the Orin's 12 cores and
is the installed configuration now.

## Result

Qwen3.8-Flash-Next IQ3_S, int8 KV. Decode is the engine-reported rate, the median of three fresh 4,096-token prompts
with 256 greedy tokens each, through `serve/server.py`. Every run measures three workloads in one server session:
**review** (the community `benchmark.py`, synthetic code review: the headline) and gufo's two single-user workloads,
**prose** (summarize synthetic prose) and **repetition** (repeat a passage), with the same prompt length and budget.

| Configuration | Review | Prose | Repetition | Texts |
| --- | ---: | ---: | ---: | --- |
| Round 2 best = installed start script (`r3-baseline-f1` / `f2`) | 35.47 / 35.61 | 18.43 / 18.58 | 16.58 / 16.44 | gate |
| This branch's head, every switch off (`r3-e075`) | 35.60 | 18.60 | 16.31 | identical |
| **Best: `STRATA_SPEC_COST` + zero-copy misses + 7 CPU workers** (`r3-e047`) | **36.82** | **25.92** | **30.78** | identical |
| Same settings at the final head (`r3-e076`, `r3-e077` with 32K needles 3/3) | 36.84 / 37.02 | 25.67 / 25.90 | 30.87 / 31.37 | identical |
| Wide windows: + `STRATA_IL_SPLIT`, spec 8 (`r3-e062`, `r3-e078`, `r3-e079` with needles 3/3) | 36.21 / 36.58 / 36.80 | 25.23 / 24.75 / 23.80 | 32.61 / 32.35 / 33.19 | identical |
| Installed start script, verified 2026-11-04 02:15 PST (`run-iq3_s.sh`, needles 3/3) | 36.98 | 25.72 | 31.12 | identical |
| Continuation's final head, every switch off (`r3-e115`) | 35.52 | 18.35 | 16.09 | identical |
| Same head, the 02:15 install's settings (`r3-e116` / `e119`) | 36.54 / 37.02 | 25.92 / 25.79 | 30.76 / 30.79 | identical |
| + 9 pinned miss workers, `STRATA_POOL_SIBLINGS=1` (`r3-e117`, `r3-e118` with needles 3/3) | 36.83 / 36.95 | 26.69 / 26.84 | 32.39 / 32.87 | identical |
| Wide windows + 9 pinned workers (`r3-e120`; `r3-e090` / `e098` in the loop) | 37.10 | 26.23 | 35.60 | identical |
| **Installed start script, verified 2026-11-04 22:01 PST** (`fast-r3b`, needles 3/3) | **36.74** | **26.32** | **32.69** | identical |

Through the start script installed at 22:01 PST, against the baselines' mean: review **+3.4%**, prose **+42%**,
repetition **+98%**, with text identical to the baselines on all nine prompts, 32K needles 3/3, the same 19,068
cache slots, prompt speed 343.7 tok/s, TTFT 12.0 s and a minimum of 11.89 GiB free memory. The engine is this
branch's head (sha256 `8964f913...`, the same binary as `r3-e115`-`e120`). Against the 02:15 install over every run
of each configuration, the 9 pinned workers are -0.4% on review (36.71 vs 36.87, inside the spread), +2.9% on prose
(26.56 vs 25.82) and +5.2% on repetition (32.57 vs 30.95). The wide-window settings with 9 pinned workers average
+13% on repetition (35.07) but vary more on review and prose (35.64-37.10, 23.88-26.23); they were not installed.

The 87.5 tok/s goal on review was not reached. The literature pass put the realistic landing for this engine on
general text at ~45-48 tok/s; this round reached 37.0.

Runs that changed the text (placement changes, so not kept under the rule) reached prose ~30 and repetition ~43:
see [What did not count](#what-did-not-count).

## What changed

All new behavior is opt-in; with none of these switches set the engine is unchanged (`r3-e075`).

- **Cost-aware draft window, `STRATA_SPEC_COST=1`** (+3.3% review; a port of upstream's rule). After each draft
  step the chain keeps the draft count that maximizes expected tokens per millisecond: expected tokens from the
  measured acceptance of drafts in each of 8 probability buckets, over the measured cost of a window of that width.
  `STRATA_SPEC_COST_TABLE=52.5,63.5,74.5,86.7` seeds the costs with the round's measured window times. Effect:
  fewer one-token windows, 74.1-74.5 instead of 75.7-76.1 ms a window at the same text. Window choice cannot change
  the output: every token is verified.
- **Zero-copy CPU misses, `STRATA_MISS_ZEROCOPY=1`** (repetition +29% alone). Decode-time expert misses turned out
  to be page-cache hits, not SSD reads (the prefill re-reads ~12 GB from the SSD; decode then finds those pages in
  RAM). Their cost was the copy that assembled each missed expert from its three GGUF slices into a stage buffer.
  The CPU kernels now read the slices in place: same bytes, same per-row kernels.
- **`--pool-workers 7`** (a setting; prose +21%, repetition +25% alone). The CPU pool dedups cores by
  `(package, core_id)`, which leaves 4 of the Orin's 12 cores working on misses. 7 workers halve the miss compute;
  11 cost the host thread ~1 ms a window. With zero-copy the two halves compose: prose +40%, repetition +86%.
- **Split wide windows, `STRATA_IL_SPLIT=1`**: 7-8 column dense GEMVs run as two 4-column passes. On the same
  windows verify drops 149 -> 133 ms at 7 columns and 157 -> 142 at 8. It makes `--spec 8` pay on repetition
  (32.6 vs 30.8) but not on review (36.2 vs 36.8).
- Measured, text identical, no gain (kept opt-in for reference): `STRATA_MISS_OVERLAP` (cold-read overlap; few
  cold reads exist), `STRATA_GU_SWIGLU` (fused gate/up + SwiGLU + quantize; window hashes bitwise), and
  `STRATA_COMMIT_BATCH` (the verifier commit's GDN and QSA work batched across layers).

The best settings are `overrides/r3-e118-sibp9-needles.json` on top of `base-overrides.json` (round 2's best): the
continuation's 9 pinned workers on top of `overrides/r3-e047-scost-zcp7.json`. To install them, follow
[round 1's fast-build guide](../2026-11-01-orin-decode-autoresearch/fast-build/README.md), which now writes round 3's
settings too.

## Why each workload sits where it does

- **Review** runs at 99.9% expert-cache hits, so it is bound by the GPU's verify window: ~37 ms fixed plus ~11.5
  ms a verified token (round 2's model, confirmed here: T1 48, T2 58, T3 69, T4 80 ms), with cliffs at the 5th
  (+22 ms) and 7th (+30 ms) column. At `--spec 8` drafts at depths 4-7 are still accepted (T8 windows accept 4.1-5.3
  drafts), so wide windows lose only through those cliffs. The fused kernels that would remove them (multi-column
  GEMVs flat to 8 columns, one hyper-connection mixer per layer) were planned but not built this round.
- **Prose and repetition** are expert-cache-miss-bound: the warm profile was learned on review, so they hit 87% and
  79%. On repetition every draft is accepted, yet before this round 193-219 ms of each 258-284 ms window was the CPU
  miss path (`r3-e001`).
  Each 0.1% of hit rate is worth ~3% of decode on review.

## Continuation, 2026-11-04 13:55-18:25 PST

The loop was restarted from the 02:15 install (12 iterations; it stopped on its deadline after a usage limit at
18:00). All changes are opt-in; with every switch off the head reproduces the baselines (`r3-e115`).

- **The miss pool on 9 of 12 cores, `STRATA_POOL_SIBLINGS=1`** (the install). Every CPU of the Orin reports
  `physical_package_id` 0 and `core_id` 0-3 inside each of its 3 clusters, with no SMT. The pool named cores by
  (package, core_id), counted 4, and pinned workers to CPUs 1-3 only (`N pool workers on logical processors 1,2,3`
  at any N; workers past the third were not pinned). Naming a core by its `thread_siblings_list` gives 12. Pinned
  to CPUs 1-9: prose +3%, repetition +5%, review unchanged. Pinned to 1-7 or 1-11 was slower on all three (7:
  36.10 / 22.55 / 28.47; 11: 35.00 / 20.75 / 24.78; with 11, no core is left for the host, I/O and CUDA threads).
- **Exact-rounding GPU misses, `STRATA_MISS_GPU_EXACT=1`**: texts identical, no gain. A diagnostic
  (`STRATA_MISS_REPLICA_CHECK=1`, `r3-e095`) found the float forms ggml-cpu uses on this board (fused Q8_K
  quantization; a fused multiply-add per IQ3_S block; `fma(X, C, Y*F)` for IQ4_NL) and GPU kernels in those forms
  reproduce the CPU's misses bit for bit (`r3-e114`, texts identical on all nine). The GPU can only reach misses held
  in a pinned RAM copy, and every copy of 2.5 GiB or more broke the bench's 6 GiB free-memory floor beside the
  19,068-slot cache (12 runs); 1.5 GiB covered too few misses to gain (35.48 / 25.06 / 29.69 with timing on).
- Measured, texts identical, no gain (kept opt-in): `STRATA_SPEC_STALE` (re-price stale window widths),
  `STRATA_COPY_MATCH` (skip the MTP chain when a lookup copy fills the window; it took the copy on every such window
  but the chain is short), `STRATA_MTP_PRIORITY=2` (drafter streams at the highest priority), `--pool-tasks`
  64 / 128, and `STRATA_IQ3S_NEON_MT=1` (decode each IQ3_S block once for all window tokens on the CPU: 47-58 vs
  40-45 ms of CPU time per repetition window). Its mode 2 (multiply, then add) changed the text: one float step is
  enough for the gate to catch.
- Dropped, never validly measured: a RAM copy ranked by another profile (all its runs hit the memory floor) and an
  IQ4_NL NEON kernel (never queued).
- Read from the logs: review's stalled requests are PLE table reads from the SSD (the 28.8 GB table cannot stay in
  RAM; 6 of 99 timed requests). Review's one lever above ~1.5% left at `--spec 4` is the dense layers at one column
  (~137 of ~180 GB/s, ~4-5 ms a window), which needs a weight re-layout that keeps results bit-identical.

## What did not count

These raised prose and repetition but changed the text, because a missed expert computed on the CPU rounds
differently from the GPU kernel. Changing which experts are resident therefore changes the output, even though
routing, top-k and the math are unchanged. Under this round's rule they are reported, not kept.

| Settings (with zero-copy + 7 workers) | Review | Prose | Repetition |
| --- | ---: | ---: | ---: |
| Adaptive cache tier every 16 windows, copies one window late (`r3-e060`, needles 3/3) | 34.96 | 29.54 | 41.79 |
| + wide windows (`r3-e063`) | 35.97 | 28.68 | 43.35 |
| Bigger cache, `--expert-cache 16400` = 21,365 slots (`r3-e048` / `e049`) | 33.79 / 33.83 | 26.33 / 28.07 | 36.67 / 36.75 |
| Mixed profile + bigger cache (`r3-e052`) | 33.40 | 30.19 | 43.13 |
| Prompt-informed refill after prefill (`r3-e055`-`e059`; code dropped) | 32.2-34.6 | 26.3-29.5 | 33.9-42.5 |

The bigger cache cost review 5% at the same 99.9% hit rate. A likely cause, not measured: the smaller page cache
sends review's remaining misses to the SSD.

Closed with text identical and no gain: `--spec-min-p` 0.7 / 0.85 (-4% / -12%), `--spec 8` without the split
(-12%), lookup chains 4 and 7, 11 CPU workers, 16 I/O threads, cold-read overlap, the fused gate/up kernel, commit
batching.

## Caveats

- **Three prompts per workload**, synthetic, with a warm expert profile learned on the review prompts. Prose and
  repetition are judged on a profile that does not fit them; that is what they measure.
- **Two of ~15 review requests stall** on ~300 ms windows (lookup-table rows or experts read from the SSD); medians
  include them.
- **Losslessness** rests on identical text on nine prompts per run and on each change keeping the same arithmetic.
  The fused gate/up kernel was also checked with window hashes (bitwise on 53 windows); the other changes were not.
- **Board state.** The owner stopped two idle services at 21:12 PST (~5 GiB more free memory). The cache size did
  not change (it is capped by `--expert-cache 14629`), texts did not change, and review ran ~1% faster afterwards,
  so runs after 21:12 compare with `r3-baseline-f1/f2`, earlier runs with `w1/w2`.
- **Invalid runs.** `r3-p010..p013` and `r3-e019..e032` measured a stale binary (the board copy of each snapshot
  kept the laptop's file times, so ninja skipped changed files) and are marked so in `notes.md`. The queue now copies
  with `--checksum` and every result records the binary's sha256.
- **The loop stopped early** at 00:03 PST (a usage limit, four failed iterations), 3.5 hours before its deadline;
  three committed experiments were never measured and were dropped from the branch. The continuation re-measured
  them (no gain).
- **The board was shared during the continuation** with another project's GPU jobs. A shared lock serializes GPU
  work, so runs waited but did not overlap; `r3-e094`'s review median (30.47) is one stalled request with no other
  job running.
- **Not upstream-ready**: measured on the Orin only.

## Files

- `program.md`: the instructions each iteration ran with.
- `notes.md`: the agents' running log, measurements and dead ends, per iteration, and the wrap-up.
- `research-ideas.md`: the agents' working notes on candidate ideas during the round.
- `results.tsv`: every measurement of the round (status, three workloads, gate, hit rate, cache slots, sha256).
- `overrides/`, `base-overrides.json`: the settings for each experiment.
- `harness/`: the scripts, with host names and paths replaced (`jetson` is an ssh alias, `/home/<user>` the board's
  home). New in this round: the board's queue runner (`harness/jetson/qrunner.sh`) that builds and measures queued
  snapshots in order, the three-workload bench, and the text gate over nine prompts (`harness/compare.py`).
  `harness/jetson/benchmark.py` adds gufo's two workloads to the community benchmark; the word pool, text
  generator and task suffixes come from gufo (MIT, `harness/jetson/LICENSE-gufo.txt`). `harness/ar_collect.sh`
  takes a lock since the continuation (two collects at once had logged one run twice).
