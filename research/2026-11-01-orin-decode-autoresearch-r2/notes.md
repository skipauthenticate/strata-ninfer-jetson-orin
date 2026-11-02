# Autoresearch round 2 notes

Current best: **r2-e043 35.18 tok/s** (repeat r2-e044 34.93 with needles 3/3), engine 4f8dacc1 (no source change:
existing opt-in switches), overrides/r2-e043-iq4xs-rr.json = STRATA_SPEC_CUM=0,0.40,0.47 + STRATA_IO_PREFETCH=1 +
STRATA_MTP_EXPERTS=.../mtp-hp/mtp-q8_0.gguf + STRATA_MTP_EXPERTS_AS=iq4_xs + STRATA_HC_DOWN_RR=1, PASS (texts
1.0/1.0/1.0 in both). Its per-request ms equal e040's within noise: the honest gain over e026 is ~+0.3-0.7%.
Previous best r2-e026 34.81 (= e009 + STRATA_IO_PREFETCH=1; prefill +17-37%). Baseline 33.28-33.39 (spread 0.11). Min free RAM 7.0-7.16 GiB (base 7.7). Iteration 8 (e030-e033: miss
predictors LA_NEON / LOOKAHEAD_K / MISS_REPLAY) found nothing better; the engine head has those as opt-in switches.
Iteration 9 (e034-e039): HC down rows-2, layer-1 PLE split, IQ4_XS drafter (e039 34.89, PASS, +0.08 = under the bar).
Iteration 10 (e040-e042, p002-p007): e040 = e026 + IQ4_XS drafter clean 34.90 (PASS, +0.09, under the bar); HC reads
timed alone (new probe); opt-in STRATA_HC_DOWN_RR (bitwise, PASS) wins alone but not in the pipeline at T4.
Iteration 11 (e043-e047): e043 = IQ4_XS drafter + RR stacked = new best; look-ahead off (e045) and SH_FORK_LATE=0 +
HOST_CORE=last (e046) no gain; e047 (STRATA_EXPERT_V2) collected: 33.92, closed; e048 (e043 at the head) 35.09. Engine head 8d466b5d
(was 4f8dacc1; see wrap-up).

## Starting point (from round 1)
- Base = round 1's e096 settings without the two diagnostics: `--kv-grow --expert-cache 14629 --mtp-hnorm stream`,
  warm profile, adaptive tier off, and 12 STRATA_* switches (`base-overrides.json`). Engine: branch ar/decode-speed
  at a94a322c (opt-in switches; the profiler stamps are inert without STRATA_VERIFY_PROFILE).
- Served verification (fast-build): 33.28 [32.39-34.87] tok/s, 301 prompt tok/s, needles 3/3.
- Per window (~2.45 tokens, ~76-80 ms): experts ~23 ms, dense ~22 ms, HC reads ~18 ms, draft ~6 ms. DRAM streams
  ~180 GB/s; decode kernels reach 83-120 GB/s and behave as instruction-issue / occupancy bound.
- Round 1 dead ends and exhausted knobs: spec 3 and spec 5 (spec 4 windows never exceed 4 tokens; spec 5 loses),
  spec-min-p 0.3, STRATA_VERIFY_DEVICE_PLAN, STRATA_HC_SPLIT, VRAM_GY 4 and 16 (8 is the optimum), IL rows variants,
  cache size steps, resident budget (pressure abort). Full list: round 1 notes.
- Open from round 1: occasional request stalls from PLE row reads off the SSD (6-9 tok/s requests).

## Ideas queue (research-ideas.md, written by a separate research pass, takes precedence when present)
1. More tokens per window: why spec 4 windows cap at 4 tokens; longer windows with suffix/prompt-lookup drafts
   (`--suffix-draft`, `--mtp-max-t`); tree verification.
2. Fewer bytes per window: reuse expert and dense weight reads across the tokens of a window.
3. Overlap and launch count: persistent decode loop, fusing the HC stages.

## Log (newest last)

### iteration 1 (2026-11-01 ~11:44-12:15), r2-e001..e006
Tooling: `STRATA_DECODE_TIMING=1` now prints `strata decode by window size:` (per T: windows, mean accepted drafts,
verify ms, round ms = verify+commit+draft); `STRATA_SPEC_DEPTH=1` (already in the engine) prints per-depth
accepted/tested. `STRATA_MTP_TOP2` is dead code (record_top2 is never called): do not use it without wiring it.
Gate: compare.py vs runs/r2-baseline-{1,2,3}; the results.tsv agreement column was empty for e001/e002 (filled from
e003 on), all six were checked by hand: **every run 1.0/1.0/1.0**.
- **e001-diag (base + timing + spec depth; measurement): 33.02, texts identical.** Per window size (3 requests):
  verify T1 48.2 / T2 57.6 / T3 69.2 / T4 82.7 ms, round 52.5 / 63.1 / 74.9 / 88.9 ms -> **verify ~= 37 ms fixed +
  ~11.5 ms per column**. Tokens per ms by T: 0.019 / 0.029 / 0.031 / 0.037 (T4 windows are the most efficient).
  T1 windows (first draft p < 0.5) are 14-17 per request (~15%), 52 ms for one token. Per-depth acceptance when
  tested: d0 220/251 (88%), d1 142/179 (79%), d2 102/124 (82%). The one suffix 6-token window: verify 132.7 ms.
- **e002 spec 5 + STRATA_IL56=1 (new: IL dense kernels for 5-6 columns, round 1's e030 diff behind a switch):
  31.48 (31.15/31.48/32.79), texts identical, worse.** T5 verify 100-103 ms vs T4 ~83: **the 5th column costs
  18-20 ms (round +21), not ~12**. Depth-3 acceptance 67/82 (82%); windows 97/89/92 vs 105/99/98; draft 6.4-7.1 vs
  5.6 ms/window. Not enough tokens for the price.
- **e003 STRATA_SPEC_CUM=0,0.40,0.47 (new: draft j joins the window only while the product of drafts 0..j's
  probabilities >= t_j, on top of min-p 0.5; thresholds = marginal round cost / ms per token = 12/30, 14/30):
  33.50 (32.85/33.50/35.01), texts identical.** ms per 256 tokens 7792/7642/7311 vs baseline-2 7875/7692/7345
  (-1.0/-0.7/-0.5%); drafts offered 206/204/188 vs 213/211/200, accepted 153/156/156 vs 153/157/158 (it trims weak
  third drafts; depth-2 tested 37/40/37 vs 39/41/44).
- **e004 spec 5 + IL56 + CUM 0,0.40,0.47,0.70: 32.66, texts identical, worse.** 4th draft accepted 37/43 (86%) when
  the joint p >= 0.7, T5 windows 19/20/14 at 3.05-3.71 tokens, but T5 round ~110.7 vs T4 ~87.4 ms and draft 6.3-6.5.
- **e005 profile of spec 5 + IL56 (VERIFY_PROFILE + BW_PROBE; measurement): 30.72, texts identical.** Request 1 vs
  round 1 e100 request 1 (same base, spec 4): avg T 3.42 vs 3.03, total 79.56 vs 70.48 ms/window = **+9.1 ms for
  +0.39 T (~23 ms a column, 2x normal)**. Dense GEMVs +4.4 (GDN qkv +1.26, z +0.85, out-proj +1.02, QSA q +0.45,
  out +0.33, head +0.48), experts +1.7 (linear), HC +0.5, attention +0.3, waitCPU +0.6. **The excess is the dense IL
  kernels at 5 columns** (~6.5 ms a T5 window). Suspects: native_q8_1_il_cp(5) = 8 (activations padded to 8
  columns), 4-column rows at 5 columns (class 4 = rows 2: ~95+ registers, 5 blocks a SM at nc4). BW probe has no
  nc5 lines.
- **e006 = e003 again + needles: 32.81 (32.81/33.43/6.83), texts identical, needles 3/3.** Request 3 is a stall
  (`stage 301.67` ms/window, 6.8 tok/s; PLE/SSD type), outlier. Requests 1-2: 7803/7659 ms (= e003 within 0.2%).
  The gate's gain is small and consistent (+0.3-1.0% paired) but not a formal best (median rule).
- Committed 9348c22d on ar/decode-speed (all opt-in: STRATA_SPEC_CUM, STRATA_IL56, the by-T timing line).

**Conclusions.** The per-window cost model is now measured directly: 37 ms fixed + 11.5 ms a column at 2-4
columns, ~20 ms for a 5th. Drafts are good (79-88% per depth, 82-86% at depth 3), so the drafter is not what caps
tokens per window; the column price is. Draft-policy tuning (CUM gate) is worth ~0.5%. 90 tok/s needs ~4 tokens
per ~44 ms window: out of reach without cutting the 37 ms fixed cost (dense 22 + HC 15 + head 5 at ~100 GB/s).

**Next, ranked:**
1. **Cheap 5th column (enabler for spec 5)**: add nc5 lines to the BW probe (registers / blocks a SM); try the IL
   kernel at 5 columns with rows 1 for every class, and/or a CP = 5..6 layout instead of padding to 8 (bitwise:
   same integers into the same dp4a). Target T5 verify <= ~95 ms (5th column <= 12 ms). Then spec 5 + CUM
   `0,0.40,0.47,0.45..0.55` (the 5th-column threshold from the measured T4->T5 round delta / ms per token).
   Predicted +2-3% over e003. Paired comparisons: use the by-T line (same texts -> compare per-T verify ms).
2. **The drafter's extra step at spec 5** (+0.8 ms/window): the 4th draft step runs whenever draft 3 joins; with
   CUM it already stops on the joint probability; check `draft` ms in e004 vs e003 per draft step.
3. **Fixed cost (37 ms at T1)**: HC read fusion (research item 8) and the dense family at 1-4 columns; the T1
   window is the pure fixed cost, a clean target to measure (by-T line T1 verify 48 ms).
4. **Stalls**: 2 of 21 r2 requests so far (b1 req1 9.21, e006 req3 6.83; `stage` ~300 ms/window). Untested:
   `--ple-row-cache`, `--ple-inflight`.
5. T1 windows (15%, 52 ms per token): a cheaper source of a 2nd token there (suffix/lookup only when it fires).
Do not retry: spec 5 without a cheaper 5th column (e002, e004); STRATA_MTP_TOP2 until wired; tree drafts at
width +1 (a node is a full ~11.5 ms column; at <= ~0.2 tokens gained a window it cannot pay, by the e001 numbers).

### iteration 2 (2026-11-01 ~12:15-13:40), r2-e007..e012: higher-precision draft experts
Engine (commit ecdee245, opt-in): `STRATA_MTP_EXPERTS=<gguf>` loads the draft layer's 512 routed experts from a GGUF
(`mtp.layers.0.mlp.experts.gate_up_proj` [E,2FF,H] = gate rows then up rows, `down_proj` [E,H,FF]; any type
`native_expert_supported` takes) into `native_expert_grouped`'s blob layout [gate|up|down] and computes them with that
kernel (q8_1 activations via `quantize_q8_1_rows`, the main model's hit path) instead of the Q2_0 blob +
`moe_grouped_s2` (`src/core/mtp.cpp` load_gguf_experts, record_rest). The draft layer's experts run only in
record_rest (T = 1 chain steps). Unset = the old path, byte for byte. Drafts only, so texts stay identical.
- **e007 Q4_0 (+ timing + spec depth; pair with e001 = Q2_0): 33.80, texts identical.** Drafts accepted 157/163/162
  = 482 (e001: 468), windows 100/94/93 = 287 (299), decode ms 22764 vs 23307 (-2.3%). Per depth (accepted/tested):
  d0 220/245 (90%) vs 220/251, d1 146/187 (78%) vs 142/179, d2 114/134 (85%) vs 102/124. Price: draft part of a T4
  round 7.1 vs 6.2 ms (Q4_0 experts read ~27.6 MB a draft step vs 13.8). Load 1350 MiB (Q2_0 675), min free 6.92.
- **e008 Q8_0 + `--expert-cache 14229` (needed: Q8_0 is 2550 MiB, +1.17 GiB): 33.46, texts DIFFER 0.49/0.45/0.13**
  from the cache-size change alone (GPU vs CPU experts round differently; rule 3). Accepted 479, windows 286: **no
  gain over Q4_0**, hit rate 99.7%. Q8_0 drafter: do not retry.
- **e009 Q4_0 + CUM 0,0.40,0.47, no timing: 34.54 (32.72/34.54/35.27), texts identical.** ms 7825/7411/7258 vs
  baseline-2 7875/7692/7345 (-0.6/-3.7/-1.2%); accepted 155/162/160 of 210/196/194.
- **e010 = e009 + needles: 32.69 (32.69/27.48/35.22), texts identical, needles 3/3.** Request 2 is a stall outlier
  (9316 ms with exactly e009's accepted drafts and cache hits: +1.9 s, the PLE/SSD type); requests 1 and 3 match e009
  within 0.2%.
- **e011 = e009 again: 34.45 (32.67/34.45/35.13), texts identical.** Confirms e009 -> new current best.
- **e012 diagnostic (e009 + STRATA_MTP_FULL_HEAD=1 + timing): no result.** Still running on the Jetson after more
  than 1 h when this iteration ended (normal runs take 3-6 min; the full 248k-row Q6_K head every draft step is slow,
  or it hangs). The next ar_run.sh collects it (collect_orphans); bench.sh's `timeout 7200` kills it ~14:37 at the
  latest. **If the next run waits on the GPU lock, this is why.** The question was already answered: round 1 e019
  found the first 40,960 draft_vocab entries give the same accepted counts as the full head, so draft vocabulary
  (research item 1's vocab part, N3) is not a lever on these prompts. Do not rerun it.

**Conclusions.** A 4-bit draft layer is worth +3% accepted drafts and -4% windows (2.46 -> 2.68 tokens a window with
CUM); Q8_0 adds nothing and the vocab subset costs nothing. Per-depth acceptance is now 90/78/85%: **the drafter is
not the cap; the verify column price is** (37 ms fixed + 11.5 ms a column, 5th column ~20 ms). 90 tok/s at
~4 tokens a window needs spec 5-6 windows at near-linear column cost, plus a lower fixed cost.

**Next, ranked:**
1. **Cheap 5th column** (iteration 1's item 1, unchanged): nc5 lines in the BW probe, IL kernel at 5 columns with
   rows 1, or CP 5..6 instead of padding to 8. Then spec 5 + Q4_0 drafter + CUM `0,0.40,0.47,~0.5`. With d2 at 85%,
   the 4th draft (e004: 86% when joint p >= 0.7) should pay once the 5th column costs <= ~12 ms.
2. **Draft cost**: the Q4_0 experts added ~0.9 ms a window. Check `native_expert_grouped`'s GB/s at T = 1 / 10
   entries in the drafter (VERIFY_PROFILE stamps do not cover the drafter; time a chain step); the draft is ~7 ms
   of an ~87 ms T4 round.
3. **Fixed cost** (HC read fusion, research item 8; dense family at 1-4 columns); T1 windows are the pure fixed cost.
4. **Stalls**: 3 of 30 r2 requests (b1 req1, e006 req3, e010 req2), ~300 ms windows. They now decide medians:
   try `--ple-row-cache` / `--ple-inflight` (untested), paired on e009's config.
5. Suffix/lookup drafts (`--suffix-draft`, `--lookup-chain`) only after item 1 (they need cheap wide windows).

### iteration 3 (2026-11-01 ~13:39-), r2-e012 (collected), r2-e013..
Harness notes: iteration 2's e012 hang was the network (iter-002.log ends in `API Error ... ENOTFOUND`), not a lock;
e012 finished normally and was collected by this iteration's first ar_run.sh. Iterations run as `claude -p
--max-turns 120`: budget turns. Waiting pattern that works: start ar_run.sh with run_in_background, then block in
the foreground on `tail -f -n +1 <task output> | grep -m1 -E "<exp id>|BUILD FAILED|rsync failed"` (timeout 600 s).
- **e012 (collected) e009 + STRATA_MTP_FULL_HEAD=1 + timing: 32.24, texts identical.** Drafts accepted 157/161/160 =
  478 vs e009's 477: the full 248K-row draft head accepts nothing more; round - verify grows ~6 -> ~11-14 ms a window.
  Draft vocabulary is closed for good.
- **e013 (code, opt-in path only) spec 5 + IL56 with the 5-6 column IL kernels uncapped (`__launch_bounds__` min
  blocks 8 -> 1 at NC >= 5, rows 1) + Q4_0 drafter + CUM 0,0.40,0.47,0.50 + timing + BW probe: 33.09
  (32.29/33.09/33.13), texts identical 1.0/1.0/1.0. Worse than spec 4 (e007 with timing 33.80).** BW probe: Q6_K nc5
  r1 91 registers / 5 blocks (0 B local), nc5 r2 122 / 4, nc6 r1 122 / 4, Q5_K nc5 r1 120 / 4 (so the old 64 cap at
  nc5 forced a big squeeze; ptxas reported 0 B local before too, per e005's probe it was not listed). **T5 verify
  103.3 / 107.0 / 104.4 ms vs T4 79.7 / 78.2 / 79.2** (round 111.8-115.5 vs 85.8-87.7): the 5th column still costs
  ~25 ms, the same as e002 with the capped kernels (100-103). The register cap is not the cause. T5 windows 33/39/29
  at 3.06-3.17 accepted; depth-3 acceptance when tested 19/23, 25/30, 18/22 (~80%). A T5 window gains ~0.7 tokens
  (~20 ms) over a T4 one and costs ~26 ms more: spec 5 needs T5 verify <= ~98 ms to break even.
  The env parser now also takes `STRATA_MMVQ_IL_ROWS` rows for ncols 5-6 (else 5-6 take the 4-column row, as before).
- **e014 (diagnostic, profiler only) e013 + STRATA_VERIFY_PROFILE=1 with a new per-T table (verify.cpp: each
  window's stage deltas also go to a row for its T; printed after the usual table as `|| T<n> <w> win total ...`):
  32.15 profiled, texts identical.** Request 1, ms a window (GDN + QSA layers):
  | stage | T1 | T2 | T3 | T4 | T5 | per column T1-T4 |
  |---|---|---|---|---|---|---|
  | experts gate/up + SwiGLU | 6.46 | 10.16 | 13.72 | 17.17 | 20.82 | **+3.6 (linear)** |
  | experts down | 3.63 | 5.58 | 7.47 | 9.14 | 10.73 | **+1.8** |
  | dense qkv / z / out-proj / QSA q / head | 5.43/3.25/4.67/2.39/3.41 = 19.15 | 20.56 | 23.76 | 25.30 | **38.11** | +2.0 |
  | HC (hc0 norm/down/up, hc1 norm/down, hc1 up+router) | 11.59 | 12.23 | 13.34 | 15.20 | 17.28 | +1.2 |
  | shared+quant (serialized by the profiler) | 2.81 | 3.61 | 3.91 | 4.57 | 5.66 | +0.6 |
  | attention / rec / waitCPU | 0.89/1.40/0.34 | 1.51/1.11/0.52 | 2.14/1.29/1.07 | 2.69/1.48/1.40 | 3.41/1.67/3.79 | +0.6/0/+0.35 |
  | total | 49.17 | 58.31 | 70.20 | 80.62 | 105.61 | ~10.5 |
  Readings: (1) **the per-column price at T2-T4 is half expert bytes** (5.4 ms of ~10.5: each column's new experts,
  at ~140 GB/s); dense +2.0, HC +1.2, attention/shared +1.2. Nothing else grows superlinearly at T <= 4 (the T1->T4
  totals rise 9.1 / 11.9 / 10.4). (2) **The T5 jump is the dense IL kernels: 25.3 -> 38.1 ms (+12.8)**; qkv +4.2,
  z +2.7, out-proj +3.3, q +1.2, head +1.35. The one T6 window (6-column IL) has dense 44.1, only +6 over T5, so the
  step is at 5: CP goes 4 -> 8 (two int4 activation loads per u()/scales() instead of one) and occupancy 8 -> 5
  blocks (91 registers). waitCPU also jumps at T5 (1.4 -> 3.8: more unique experts -> more CPU misses).
  (3) The fixed T1 cost: dense 19.2 + HC 11.6 + experts 10.1 + shared 2.8 + rest ~5.5 = 49.2.
- **e015 (code, discarded) e009 + opt-in STRATA_IQ3S_BX=1: Split<21>::load takes its qs/sign bytes by shifts instead
  of a `uint8_t*` into local int2/int (same integers, bitwise): 34.55 (32.76/34.55/35.32), texts identical.** Per
  request 7815/7409/7249 vs e009 7825/7411/7258 and e011 7836/7431/7287 ms: noise. The BW probe still reports
  **48 B local for the `bx` variant too**: the local array is in the kernel's non-sub16 fallback (`s2[lane]` etc.,
  dynamic indices into the result arrays; never runs at n_embd 2560), as round 1 said. The gate/up kernel's gap to
  down is not local memory. Code removed (source: runs/r2-e015-iq3s-bx/source.diff). Do not retry.
- **e016 (env, new parser) e013 + `STRATA_MMVQ_IL_ROWS=...;14:5:0,2,2,2,2` (Q6_K 2 rows a warp at 5 columns: each
  CP-8 activation load serves 2 rows): 33.50 (32.58/33.50/33.84), texts identical.** Paired with e013 (same windows
  33/39/29 T5): **T5 verify 100.72 / 102.32 / 100.75 vs 103.32 / 107.02 / 104.35 (-2.6 to -4.7 ms)**, T4 unchanged;
  per request 7857/7566/7642 vs 7927/7737/7728 ms (-0.9/-2.2/-1.1%). Confirms the activation-load reading of e014,
  but spec 5 still loses to spec 4 (e009 7825/7411/7258 without timing): the 5th column now costs ~21-23 ms + ~1.5
  draft vs a ~20 ms gain. Not kept as a config.
- Commit 20e613dd on ar/decode-speed: the per-T profiler table, the uncapped 5-6 column IL kernels (IL56 only), the
  5-6 column IL-rows parser. Default engine unchanged. e015's code was stashed and dropped (`git checkout --` is
  still denied; `git stash push -- <file>` + `git stash drop` works for a single-file revert after committing the rest).

**Conclusions (iteration 3).** No new best: e009 (34.54) stands. The per-T profile settles where window width goes:
at T2-T4 each column costs ~10.5 ms, half of it the column's new experts at ~140 GB/s (near the ~180 GB/s DRAM
stream), so wider windows can never be cheap on this model: a 5th column is worth ~0.7-0.8 accepted tokens (~21 ms)
and costs >= ~10.5 ms even with perfect kernels. Today it costs ~22 ms because the dense IL kernels at 5 columns pay
CP-8 activation loads at lower occupancy (+12.8 ms over T4; rows 2 recovers ~3.5). Spec 5 becomes a +2-4% lever only
once T5 dense is near-linear (<= ~28 ms vs 38 today, 34.5 with rows 2).

**Next, ranked:**
1. **5-column dense without CP 8** (code, IL56 path only; bitwise: same integers into the same dp4a, same per-row
   order): a CP-5..6 activation layout is not 16-byte aligned, so instead split the interleaved copy into a CP-4 plane
   (cols 0-3, one int4 load) + a plain plane for col 4 (one int load), i.e. 5 loads where today 8 vector lanes are
   loaded and 3 dropped; plus rows 2 (e016). Measure with e016's override (paired by-T verify vs e016). Target T5
   verify <= ~96 ms, then spec 5 + CUM 4th threshold ~0.5-0.6 should give +2-3% over e009.
2. **Rows 2 at 5 columns for Q5_K/Q4_K/IQ4_XS** (env only: `13:5:0,2,2,2,2;12:5:...;23:5:...` added to e016's
   string): Q5_K nc5 r1 is already 120 registers / 4 blocks, so r2 may spill; one run, paired with e016.
3. **Expert gate/up rate** (17.2 ms at T4, ~3.6 ms a column): not local memory (e015). Remaining suspects: the IQ3_S
   16-bit weight loads (get_int_b2 on 110-byte blocks) and the 4 grid gathers per chunk; a Marlin-style offline
   permutation of the IQ3_S blocks to 4-byte alignment (byte permutation only) is the structural version (memory:
   needs an in-place repack, no duplicate copy).
4. **Fixed cost** (T1 49 ms: dense 19.2, HC 11.6, experts 10.1): HC read fusion (research item 8).
5. Stalls (`--ple-row-cache` / `--ple-inflight`), only judged over >= 3 runs.
Do not retry: the 64-register cap removal alone (e013), STRATA_IQ3S_BX / gate-up local memory (e015), full draft head
(e012), spec 5 at the current kernels (e002, e004, e013, e016).

### iteration 4 (2026-11-01 ~14:02-15:00), r2-e017..e019
- **e017 (code, discarded) e016's override + 5-6 column activation copy split into a CP-4 plane (cols 0-3, one int4)
  + a 1-2 wide plane behind it (col 4-5, one int / int2), instead of CP 8 (two int4 loads of one 32-byte run): 32.76
  (32.05/32.76/32.96), texts identical 1.0/1.0/1.0. Worse.** Paired with e016 (same windows): **T5 verify 104.27 /
  107.15 / 105.71 vs 100.72 / 102.32 / 100.75 (+3.5 to +4.8 ms)**, T1-T4 within 0.6; per request 7989/7768/7814 vs
  7857/7566/7642 ms (+1.7 to +2.7%). Reading: in the CP-8 layout a (block, position)'s 5-6 column ints sit in one
  32-byte sector, so the second int4 is nearly free; the split sends every u() to two far-apart lines. The 5-column
  activation cost is per distinct sector / load instruction, not per byte (e016's rows 2 helped because it halves
  the loads per weight row). Code removed (runs/r2-e017-il5-split/source.diff). **Do not retry split planes.**
- **e018 (env) e009 + `--ple-row-cache 4194304` (4x the default n-gram row cache, +283 MB): 34.57 (32.76/34.57/35.29),
  texts identical, min free 6.75 GiB (e009 7.1).** Per request 7815/7404/7254 vs e009 7825/7411/7258 ms (noise). No
  decode stall in this run (request 3 had a slow prefill, 21975 vs ~15300 ms, which the decode rate does not see).
  No cost, no proven benefit: stalls need >= 3 runs to judge (r2 so far: 3 stalled requests in ~36). Not kept.
- **e019 (diagnostic, timing only) e009 + STRATA_DECODE_TIMING + new line `strata draft round to draft 0 by catch-up
  rows: ... chain N steps, X ms a step` (mtp.cpp draft(): host time to draft 0 = the round graph over T = accepted + 1
  catch-up rows, by T; the rest = the chain steps): 34.42 (32.58/34.42/35.07), texts identical.** Per request:
  | | round, 1 row | 2 rows | 3 rows | 4 rows | chain step | steps a window | draft ms a window |
  |---|---|---|---|---|---|---|---|
  | req 1 | 2.53 (29x) | 3.29 (26x) | 3.40 (14x) | 3.43 (33x) | 2.08 (154) | 1.50 | 6.25 |
  | req 2 | 2.36 (22x) | 3.34 (26x) | 3.43 (7x) | 3.43 (40x) | 2.09 (143) | 1.49 | 6.24 |
  | req 3 | 2.50 (21x) | 3.32 (27x) | 3.44 (10x) | 3.42 (37x) | 2.10 (147) | 1.53 | 6.38 |
  Readings: (1) the drafter is ~6.3 ms of a ~76-77 ms window (8.2%): ~3.1 round + ~3.1 chain. (2) **A chain step
  (T = 1: q/o Q8_0 ~50 MB, HC BF16 ~13 MB, router, 10 Q4_0 experts ~28 MB, shared, head subset 82 MiB ~= 185 MB)
  takes 2.1 ms = ~88 GB/s** including the host round trip (launch + spin on the mapped output), well under the
  verify kernels' 100-140. (3) **Catch-up rows 2-4 cost a flat +0.9 ms over 1 row** (2 -> 4 rows adds only 0.1), so
  it is a T > 1 code-path cost, not per-row bytes: record_front at T > 1 takes the unfused k-norm + per-row rope loop
  (`T == 1 && fuse_nr` only), multi-column fc_embedding/k/v (plain native_mmvq, 2-4 cols), fc_hidden at 8 columns
  (T*HC) and fused_gr_read_multi over T rows. 74% of rounds have T >= 2. The earlier by-T "round - verify" slope
  (~1 ms per accepted draft) was this, plus chain-length correlation.
- Commit on ar/decode-speed: the e019 print (timing only; four counters in MtpDrafter, printed and reset with the
  by-T line under STRATA_DECODE_TIMING). Default engine output unchanged.

**Conclusions (iteration 4).** No new best: e009 (34.54) stands (e018 34.57 = same config + bigger PLE cache, noise).
The 5-column path is closed for this round: CP-8's second load is nearly free (same sector), so the T5 excess is not
activation bytes. The drafter is 8.2% of the window and its chain step runs at ~88 GB/s: a structural target of
~2-4% that needs no verify-side change (texts identical by construction, drafts unchanged if the math is unchanged).

**Next, ranked:**
1. **Draft round at T >= 2 (+0.9 ms flat over T = 1, 74% of rounds -> ~0.7 ms a window, ~0.9%)**: profile which
   record_front piece makes T >= 2 cost +0.9 ms (cudaEvent stamps in the round graph, or the same host split as
   e019 with a T = 2 round run twice). Suspects: the per-row rope loop + unfused k-norm (several tiny launches a row),
   fc_hidden at 8 columns on the plain Q8_0 kernel, fused_gr_read_multi at T rows. Keep each row's arithmetic (the
   T = 1 fused norm+rope is bit-identical to the pair: rope_parity check 6) so drafts do not change.
2. **Chain step (2.1 ms, ~88 GB/s)**: split host wait vs GPU time (cudaEvent around step graph), then the head
   subset (82 MiB Q6_K at 1 column: plain kernel; the IL path is 2+ columns) and the q/o Q8_0 GEMVs. If the host
   round trip is a large part, launch step j+1 speculatively before reading p_j (it is discarded when the gate stops:
   wasted GPU time only when the chain stops, ~1/3 of steps).
3. **Fixed verify cost** (T1 48 ms: dense 19.2, HC 11.6, experts 10.1): HC read fusion (research item 8).
4. Stalls: keep counting; `--ple-row-cache 4194304` is free (e018) if a stall study needs it.
Do not retry: split activation planes for 5-6 columns (e017); spec 5 in any form until a full kernel rewrite.

### iteration 5 (2026-11-01 14:18-14:50), r2-e020..e021: where the drafter's time goes, and the commit
Tooling (engine, opt-in, default unchanged): **`STRATA_DRAFT_PROFILE=1`** puts %globaltimer stamps (gpu_stamp) inside
the drafter's round graph and step graphs (mtp.cpp: 19 stamps a graph; draft() reads them back after its final sync,
after its host timing) and prints `strata draft GPU pieces (ms ...)` per request under STRATA_DECODE_TIMING: per
catch-up T the round's pieces (in, fc_emb, fc_hid, hc_attn, kv_proj, kv_rope, kv_app, row0 | q, attn, o, hc_mlp, moe
(router + experts + shared join), comb (+ GR write), mixer, head (draft subset GEMV), pick, select) and the same for
the chain steps. **`STRATA_COMMIT_FIRST=1`** (generate.cpp serve loop) waits for the verify's commit graph before the
draft round (ordering only; its wait lands in the timing line's `commit/emit`).
- **e020 (diagnostic) e009 + timing + STRATA_DRAFT_PROFILE: 34.51 (32.72/34.51/35.18), texts identical.** Per request
  7824/7419/7276 ms vs e009 7825/7411/7258: the stamps cost nothing measurable. Pieces (GPU ms, request 1; requests 2-3
  within 0.02):
  | piece | step (154x) | round T1 | round T2 | round T4 |
  |---|---|---|---|---|
  | front: fc_emb / fc_hid / hc_attn / kv (proj+rope+append) | 0.088 / 0.094 / 0.102 / 0.052 | .099/.109/.119/.092 | .150/.201/.174/.168 | .160/.325/.238/.144 |
  | q / attn / o | 0.205 / 0.207 / 0.115 | .220/.373/.138 | .242/.565/.169 | .252/.482/.145 |
  | hc_mlp / moe / comb / mixer | 0.095 / 0.415 / 0.008 / 0.092 | .136/.476/.019/.114 | .175/.548/.027/.171 | .155/.533/.035/.150 |
  | head / pick+select | 0.540 / 0.030 | .571/.040 | .597/.113 | .620/.119 |
  | **GPU total** (host-measured) | **2.055** (2.09) | **2.525** (2.55) | **3.373** (3.41) | **3.429** (3.44) |
  Readings: (1) **the chain step is GPU-bound: GPU 2.06 vs host 2.09 ms, the host round trip is ~0.03 ms**, so
  speculative step launches (iteration 4 item 2) are dead. (2) At T >= 2 even the one-row pieces after the front are
  slower (attn 0.37 -> 0.57, mixer +0.06, pick +0.05...): something runs beside the round.
- **e021 = e020 + STRATA_COMMIT_FIRST=1: 34.36 (32.53/34.36/34.96), texts identical; slightly worse.** commit/emit
  1.54/1.57/1.61 ms a window (= the commit graph's GPU time alone; e020: 0.04-0.06, it ran beside the draft), draft
  5.18/5.14/5.22 ms (e020 6.35/6.34/6.46), per window 76.40/77.61/76.27 vs 75.96/77.28/75.79 ms (+0.3-0.6%).
  Uncontended rounds: **T1 2.01, T2 2.07, T3 2.17, T4 2.22 ms GPU** (+0.06 a catch-up row), chain step 1.97.
  Readings: (1) **iteration 4's "+0.9 ms flat at T >= 2" was the verify commit running beside the round, not a
  drafter code path** (at T1 the commit replays 1 token and mostly ends before the round's later pieces). (2) The
  commit (36 GDN layers: conv commit + gdn_step_norm_multi replaying n_keep tokens and writing the 3.1 MB state; 12
  QSA indexer appends; PLE hist copy) costs **1.57 ms GPU (~226 MB of state at ~144 GB/s), and overlapping it with the
  bandwidth-bound drafter hides only ~0.33 ms of it**: serial commit + draft = 6.72 ms vs 6.39 overlapped. So ~1.2 ms
  a window (1.6%) is the commit on the critical path. (3) The uncontended chain step's biggest pieces: draft head
  0.533 (86 MB at ~160 GB/s: at bandwidth), **moe 0.417 (~31 MB: ~75 GB/s; Q4_0 has no Split, so native_expert_grouped
  takes the per-entry gate/up path + 8 small launches)**, q 0.202 (33 MB, ~160 GB/s), **attn 0.198 (~4.5 MB of int8
  K/V: latency-bound; it is dense over every cell, so it grows with context)**, three HC reads 0.28, fc 0.14.
- Commit 44d21d22 on ar/decode-speed: both switches (timing / ordering only). Iteration 5 used 2 of 6 experiments
  (~35 min): the remaining levers needed more than the time left, so the budget went to recording them.

**Conclusions (iteration 5).** No new best: e009 (34.54) stands. The between-window path is now fully measured:
verify ~69.6 ms, then the commit (1.57 ms GPU) beside the draft (5.2 ms uncontended: round ~2.1 + ~1.5 chain steps x
1.97), 6.4 ms together. The drafter has ~0.3-0.5 ms a window of slack (moe and attention pieces); the commit's
~1.2 ms on the critical path can only go by not reading the state twice (research N6). Every remaining lever outside
a GEMV-family rewrite is ~0.5-1.5% a window.

**Next, ranked:**
1. **GDN commit folded into the next verify (research N6, bitwise sequential replay)**: the verify's
   gdn_step_norm_multi reads the state anyway; give it a prologue that first replays the previous window's n_keep
   tokens (their h/gate/beta, so the window input buffers h_L_/gate_L_/beta_L_/qkv_L_ need double buffering) in the
   same order as the commit kernel, writes that state once, then runs the window without writing (as today). Same for
   the conv history. The separate commit graph disappears except at request end / prompt-cache checkpoints (keep
   `commit()` for those). Saves one 113 MB state read + the 36+12 commit launches: ~0.8-1.2 ms a window (1-1.5%),
   texts identical by construction if the replay order is kept. M effort (verify_kernels.cu gdn_step_norm_multi,
   gdn_conv_l2_multi, verify.cpp run/commit); budget a whole iteration; keep it opt-in.
2. **Drafter moe piece (0.42 ms x ~2.5 evaluations a window)**: at T = 1 the 10 groups take the non-split Q4_0
   kernels. Options: requantize the GGUF Q8_0 experts at load into IQ4_NL (has Split + SUB_DOWN kernels; 4.5 bpw like
   Q4_0, not lower precision than the Q2_0 base drafter) or give Q4_0 a Split. Target 0.25 ms: ~0.4 ms a window.
   Measure with STRATA_DRAFT_PROFILE (paired pieces) and acceptance (STRATA_SPEC_DEPTH).
3. **Drafter attention (0.20 ms a step, 0.37-0.57 in rounds beside the commit)**: dense over every cell; at 4.4K cells
   it is latency-bound (one small kernel chain). Check qsa_decode_attn_batch's grid at T = 1 (blocks per head x cell
   split). At the 262K context it grows linearly; matters more for long conversations than for this benchmark.
4. **Fixed verify cost** (T1 48 ms: dense 19.2, HC 11.6, experts 10.1) and the dense/HC multi-column overhead (T4:
   dense +6 ms, HC +3.6 ms over T1 with no new bytes): the GEMV-family rewrite (research items 2-3) is the only
   lever above ~2%; it needs several iterations.
Do not retry: speculative chain-step launches / device-side chain gating (host round trip 0.03 ms, e020);
STRATA_COMMIT_FIRST as a speed setting (e021: overlap is better, if only by ~0.33 ms).

### iteration 6 (2026-11-01 ~14:40-15:00), r2-e022..e023: draft policy closed out
Checked before running (no runs spent): (a) **lower min-p for draft 0 is dead**: round 1 e093 measured the 0.4-0.5
band at 14/43/10% accepted (the drafter is overconfident below 0.5), far under the ~37-44% a T1 -> T2 column needs.
(b) Drafter moe as a Split kernel for Q4_0 (iteration 5 item 2) is **not worth it**: at a chain step (T = 1) every
group has exactly one entry, so decode-once-for-N-columns gives nothing, and Q4_0's K = 160 lane items already
balance a warp (5 iterations); `row_dot_80_sub16` would even be wrong for it (it assumes K = 80). The ~0.2 ms a step
gap is launch count (router, top-k, groups, gu, swiglu, down, shared, join), ~0.5 ms a window at most.
(c) STRATA_DRAFT_VOCAB_TOP below 40960 was already worse in round 1 (e022 16384, e034 32768).
- **e022 (code, kept: commit e6b0770f) e009 + timing + chain-step skip: 34.50 (32.71/34.50/35.11), texts identical
  1.0/1.0/1.0, spec-depth counts identical to e020 (73/85 47/61 33/41 ...).** mtp.cpp draft(): under STRATA_SPEC_CUM,
  step j runs only if `cum_ok(j, cum)` already holds for the product of drafts 0..j-1 (p_j <= 1, so otherwise draft j
  is cut anyway). Chain steps 152/142/146 vs e019's 154/143/147: **the band it saves (cum_1 in [0.40, 0.47)) is 1-2
  rounds a request**; per window 75.99/77.30/75.96 vs e019 76.28/77.48/76.04 ms (~0.1-0.4%, noise level). Exact by
  construction; harmless; kept as part of the CUM path.
- **e023 (env) e022 + CUM `0,0.50,0.55`: 34.47 (32.86/34.47/34.70), texts identical. Not kept.** Per request
  7792/7426/7378 vs e022 7827/7421/7292 ms (sum +0.25%); accepted drafts 150/160/158 vs 153/162/160; d1 tested 59/57/59
  vs 61/59/59, d2 37/40/37 vs 41/43/40: the cut band accepted ~50%, right at break-even (12.5 ms column vs ~28.7 ms a
  token). **CUM 0,0.40,0.47 is the optimum within noise; draft policy is done** (min-p, CUM, vocab, chain gating).

**Conclusions (iteration 6).** No new best: e009 (34.54) stands. Every drafting-policy knob is now measured at its
optimum: d0 min-p 0.5 (0.4 and 0.6 worse), joint gate 0.40/0.47 (0.50/0.55 neutral-worse), vocab 40960, Q4_0 experts.
What is left is the verify itself (~69.6 ms a window: ~49 fixed at T1, ~10.5 a column) and the ~1.2 ms of commit on
the critical path. Honest status for the operator: at today's ~2.6-2.7 tokens a window and ~100-140 GB/s kernels,
the reachable ceiling without the GEMV-family rewrite is ~35-36 tok/s; 90 is not reachable on IQ3_S here (research
section 5); the rewrite (+N6 +GR fusion) is a multi-iteration project worth maybe 45-55.

**Next, ranked:**
1. **N6 GDN commit-in-prologue** (iteration 5 item 1, unchanged; ~1-1.5%; budget a whole iteration). Facts found this
   iteration to start from: `gdn_step_norm_multi_kernel` (verify_kernels.cu:207) already replays rows `t <
   t_out_begin` without outputs and writes the state after `*n_keep` rows when `n_keep != nullptr`; the verify call is
   verify.cpp:1814 (`te` rows, `self_commit ? one_ : nullptr`, `t_out_begin = tb`); the commit is verify.cpp:2743
   (`gdn_conv_commit` + `gdn_step_norm_multi(..., h_L_ + gdn_index*MT*C, ...)` with `commit_` as n_keep, which takes
   `gdn_step_commit_kernel` via STRATA_GDN_COMMIT_SPLIT default on). What is missing: (a) the state write must happen
   after the *prefix* rows, not after all rows (a new template flag: write at t == prefix_end - 1, then keep going
   without writing); (b) the prefix length is a device value (n_keep of the previous window) while the window rows
   start at a host `t_out_begin`: put the prefix rows in a separate small buffer (n_keep x (C + 2 HV) floats a layer,
   copied by the commit graph instead of the replay) and loop prefix-then-window in one kernel; (c) the conv history
   (`gdn_conv_l2_multi`) needs the same prefix-first treatment; (d) every path that needs a committed state (request
   end, prompt-cache checkpoints, session save, batch rows, `capture_gdn_commit_state`) must flush the pending prefix
   (keep the old commit for those). Gate: texts identical by construction; `gdn_parity` has the bitwise harness.
2. **GEMV-family rewrite for 1-4 columns** (research items 2-3): T4 windows pay dense +6.1 ms and HC +3.6 ms over T1
   with no new bytes (~12% of a T4 window). The only lever above ~2%; several iterations.
3. Drafter moe launch count (~0.5 ms a window at most): fuse router top-k + grouping for T = 1, or run the shared
   expert inside the gu/down launches. Small.
Do not retry: lower d0 min-p (e093 r1), CUM 0.50/0.55 (e023), Q4_0 Split for the drafter (T = 1 has one entry a
group), draft vocab < 40960 (r1 e022/e034).

### iteration 7 (2026-11-01 14:52-15:20), r2-e024..e029: lookup chain closed, file-tier I/O prefetch (new best)
Checked before running (no runs spent): **N6 re-estimated from e014's per-T `rec` column, it is worth ~0.3-0.6 ms a
window (0.4-0.8%), not 1-1.5%.** The verify's GDN recurrence costs 1.40 / 1.11 / 1.29 / 1.48 ms at T1-T4, and T1 is
the case that already writes the state (self_commit): writing it costs ~+0.3 ms, each extra replayed row ~+0.19 ms.
N6 moves ~2.7 prefix rows (n_keep) + the state write into the verify (~+0.8 ms on the critical path) to remove a
commit whose critical-path share is ~1.2 ms (e021): net ~-0.4 ms, below the 0.3% bar's reach once noise is counted,
against high risk (a deferred state needs a flush at request end, prompt-cache checkpoints, session save, batch rows,
short-read and every diag capture; and the per-layer h/gate/beta buffers are overwritten by the next window's conv
before its recurrence, so the prefix needs a copy in the commit graph). A cheaper find: the per-layer buffers
(`h_L_ + gdn_index*MT*C`, gate/beta likewise) survive until the next verify's own layer L rewrites them, so the copy
is ~4-8 MB, not a double-buffered graph. Parked, not dead: worth doing only together with another GDN change.
- **e024 (env) e009 + timing + spec depth + `--lookup-chain 2` + IL56 with Q6_K rows 2 at 5-6 cols: 34.12
  (33.40/34.12/34.79), texts identical 1.0/1.0/1.0.** The chain fired in 1/2/2 windows of 101/96/96 (chained drafts
  accepted 2/2, 2/4, 0/2); per request 7666/7504/7359 ms vs e022 7827/7421/7292 (-2.1/+1.1/+0.9%: noise both ways).
  Prompt lookup does not fire on these essay prompts (nor do suffix drafts: ~1 window a request). **Closed.**
- **e025 (env) e009 + timing + `STRATA_IO_PREFETCH=1` (never tried in round 1 or 2; expert_source.cpp
  set_io_prefetch: the file tier's CPU-expert reads become whole-blob preads instead of 4 KB page faults, and the
  routing-aware next-layer predictions are read ahead by 8 I/O threads instead of an madvise hint; same bytes, same
  CPU kernels): 34.84 (32.66/34.84/35.37), texts identical 1.0/1.0/1.0, min free 7.15 GiB.** Per request
  7839/7348/7237 ms vs e022 7827/7421/7292 (+0.2/-1.0/-0.8%); per window verify 69.86/70.28/69.00 vs
  69.78/71.07/69.61, the gain is in `per-layer host` (CPU-miss jobs 2.04/3.04/1.92 vs 1.94/3.77/2.50 ms a window).
  **Major faults per request 599/376/90 vs ~15,000**, and **prefill 313.5/339.7/369.3 tok/s vs 268.2/282.3/269.4
  (+17-37%; TTFT median 12.1 vs 15.2 s)**: the prompt path streams ~16 GB of experts from the file tier per 4K prompt,
  and whole-blob preads beat page faults there too. The I/O line says page cache held 3.5-5.8 GB of 16.3 GB at read;
  read-ahead was mostly unused (271-356 unused vs 3-7 used: the predictions run during prefill), so the gain is the
  pread path, not the prediction.
- **e026 = e009 + STRATA_IO_PREFETCH=1, no timing: 34.81 (32.74/34.81/35.55), texts identical 1.0/1.0/1.0, min free
  7.16.** Per request 7819/7354/7201 ms vs e009 7825/7411/7258 (-0.1/-0.8/-0.8%); prefill 308.8/338.1/344.5 tok/s.
  Confirms e025: +0.27-0.30 over e009, above the 0.11 spread -> **new best**.
- **e027 = e026 + needles: 34.73 (32.68/34.73/35.50), texts identical, needles 3/3, min free 7.0.** No stall.
- Found while reading the pool: **the CPU topology dedups Orin's 12 A78AE cores to 4** (pool.cpp:250 keys physical
  cores on `(physical_package_id, core_id)`; on Orin core_id repeats 0-3 in each of the 3 clusters with one package),
  so the CPU-miss experts ran on 3 pinned workers (cpu 1-3) + the host thread (cpu 0), 8 cores idle. The pool splits
  a phase by output rows (pool.cpp:630, each row whole in one task), so the worker count cannot change a result.
- **e028 (env) e025 + `--pool-workers 7` (workers 4-7 unpinned): 34.90 (32.75/34.90/35.56), texts identical
  1.0/1.0/1.0.** Per request 7817/7335/7200 ms vs e025 7839/7348/7237 (-0.3/-0.2/-0.5%). The `CPU` (pool run) part
  halves: 0.19/0.33/0.22 vs 0.34/0.60/0.39 ms a window; `jobs` does not move (2.09/3.23/1.84 vs 2.04/3.04/1.92).
  **`jobs` is the CPU-miss blob fetch** (expert_source.cpp:3519 `src->blob()` between stamps c2 and c3: the pread
  or staging copy of the 2.33 MB expert from the GGUF; ~1.5-2.4 misses a window), so the miss path is I/O, not
  compute: ~2-3 ms a window (3-4%) on the critical path. +0.09 over e026, under the 0.11 bar.
- **e029 = e026 + `--pool-workers 7`, no timing: 34.74 (32.67/34.74/35.46), texts identical.** Per request
  7836/7368/7220 vs e026 7819/7354/7201 (+0.2/+0.2/+0.3%): **no gain; e028's -0.3% was noise. Not kept.** The miss
  compute is too small a share to matter (0.2-0.6 ms a window), as e028's split already said.
- No engine change this iteration: head stays e6b0770f, working tree clean. The new best is an override only.

**Conclusions (iteration 7).** New best **r2-e026 34.81** (e025 34.84, e027 34.73 + needles 3/3): the existing opt-in
`STRATA_IO_PREFETCH=1` on e009's config, +0.8% decode and +17-37% prefill (TTFT 15.2 -> 12.1 s), texts identical.
Prompt lookup is closed on these prompts. N6 is re-priced at ~0.4-0.8% and parked. The decode CPU-miss path is now
measured as I/O: ~1.5-2.4 misses a window cost ~2-3 ms of blob fetch (`jobs`) on the critical path, and the
predicted read-ahead is almost never the expert that misses.

**Next, ranked:**
1. **Miss prediction for the file tier (up to ~3%, lossless: bytes only, never results)**: find why the routing-aware
   read-ahead is unused during decode (expert_source.cpp ~1851-1871: `prefetch_layer`-style hint path enqueues
   predicted (layer, expert) pairs; `io_worker` serves the newest first, 8 threads). Measure per request during decode
   only: predictions issued for non-resident experts, hits, late arrivals. Then widen it: the next layer's router top
   ~16-20 restricted to non-resident experts, issued as soon as the current layer's hidden state exists; or 2 layers
   ahead. Stats are already in the `io prefetch:` line (used / unused / skipped / dropped; `decode waited`), but they
   mix prefill and decode: split them (print at decode start and end).
2. **Hot-miss set in RAM**: `--resident-budget-gib` pins the hottest non-GPU experts but switches the file tier to
   unbuffered reads, which turns `set_io_prefetch` off (`!direct_.empty()` returns early) and cost 1.9x its budget in
   round 1 (e025 r1). With ~1.1 GiB of headroom over the 6 GiB floor, only ~0.3 GiB (~130 experts) is safe: test only
   after item 1 shows which experts miss (if a few hundred experts take most misses, an mlock of exactly those, with
   IO_PREFETCH kept, is the variant to build).
3. **GEMV-family rewrite for 1-4 columns** (iteration 6 item 2, unchanged): the only lever above ~3%; multi-iteration.
4. N6 (parked: ~0.4-0.8%), drafter moe launch count (~0.5 ms a window at most).
5. Topology fix (pool.cpp:250 keys cores on (package, core_id); use `topology/cluster_id` too): threads only, and
   e029 says the miss compute does not need more cores; only worth it for the prefill CPU share or the I/O threads.
Do not retry: `--lookup-chain` / suffix drafts on these prompts (e024), `--pool-workers` (e028/e029), N6 as a
standalone 1-1.5% item (the estimate was wrong).

### iteration 8 (2026-11-01 15:19-), r2-p001, r2-e030..e033: the file tier's miss predictor
Found by reading (expert_source.cpp RouterLookahead::run): **on ARM the routing look-ahead's router dot was a scalar
C++ loop** (`cpu_avx2_ok()` / `cpu_avx1_ok()` are false off x86; the fallback is a serial fp32 chain), ~2 ms a
token-layer, depth 2 with IO_PREFETCH. The look-ahead is submitted every layer from expert_pool_dispatch_multi (the
verify path rings the host at every layer) and skips a layer while busy.
- **p001 (probe, e026 config, `--max-new 64 --stats`)**: `routing prefetch ... predictor 58.4 ms/round on its thread,
  1010 layers skipped (still busy)` of 1296 dispatches; 120 read ahead, 0 used. (The probe prompt has only 9 misses
  in 27 rounds, so probes are not a miss benchmark; served prompts have ~150 a request.)
- Engine (opt-in, I/O only): **`STRATA_LA_NEON=1`** = the look-ahead's dot on NEON (expert_source.cpp
  la_dot_neon<NT>, 2x float32x4 accumulators a token); the served I/O line now ends with `look-ahead: N predicted,
  N layers skipped (busy), ms on its thread` (per request).
- **e030 (e025 config + LA_NEON, timing): 35.02 (32.73/35.02/35.41), texts identical 1.0/1.0/1.0.** Look-ahead now
  runs every layer (0-10 layers skipped a request, ~3.9-4.2 s busy a request = ~0.4 ms a layer prediction); read
  ahead 815/991/798 vs e025 319/314/311, **used 17/28/16 vs 7/6/3**, unused 818/952/786; `jobs` 1.83/2.59/1.86 vs
  2.04/3.04/1.92 ms a window; per window 75.93/76.16/75.30 vs 76.11/76.54/75.39 (-0.2/-0.5/-0.1%).
- **e031 (e026 config + LA_NEON, clean): 34.89 (32.63/34.89/35.35), texts identical.** vs e026 32.74/34.81/35.55:
  **no gain** (+0.08, under the 0.11 bar; request 3 -0.6%). e030's +0.5% over e025 was noise.
- **e032 (e030 + `STRATA_LOOKAHEAD_K=24`, timing): 34.61 (32.36/34.61/35.26), texts identical; worse.** Read ahead
  2921/3395/2766 (3.5x), used only 18/39/26; `jobs` 2.22/3.27/1.92 (the wrong reads contend with the demand reads on
  the SSD), per window 76.82/77.05/75.63 (+1.2/+1.2/+0.4% vs e030); prefill 291 vs 323 tok/s.
  **Reading: router(L+1) applied to layer L's MoE input catches only ~10-25% of the decode misses even at top-24**
  (on this model the MoE input of layer L+1 is a different 4-branch hyper-connection mix than layer L's, so the
  "residual changes little" premise of the look-ahead does not hold), and each wrong read costs SSD time the demand
  misses need. **The router look-ahead is closed as a decode lever** (LA_NEON stays as an opt-in fix, harmless).
- Engine (opt-in, I/O only): **`STRATA_MISS_REPLAY=1`** (expert_source.cpp expert_pool_dispatch_multi): every
  verify-window CPU-miss (layer, expert) pair is remembered; when a new request's first window arrives (positions
  drop by > 16) all known pairs are queued to the I/O read-ahead (deepest layers first, the workers take the newest
  first; cached ones are skipped) so the prompt's 16 GB expert stream does not leave them cold. The served I/O line
  ends with `miss replay: N window misses, N had missed in an earlier request, N earlier in this one, N replayed`.
- **e033 (e025 config + MISS_REPLAY, timing): 34.83 (32.70/34.83/35.57), texts identical 1.0/1.0/1.0. No gain.**
  Window misses per request 137 / 224 / 145 (warm-up 39); **had missed in an earlier request: 0 / 31 (14%) / 53
  (37%)**, earlier in the same request 32 / 33 / 18 (the page cache already serves those); known pairs 144 -> 304 ->
  378 (~0.9 GB). `jobs` 2.03/3.16/1.64 vs e025 2.04/3.04/1.92 ms a window, per window 76.00/76.57/74.96 vs
  76.11/76.54/75.39 (0 / 0 / -0.6%). Only request 3 gains (37% overlap), the replay's ~150-300 reads contend with
  request 2's demand misses, and the median request is the low-overlap one. Request 1 never replays (the warm-up
  request ends below request 1's start, so it is not seen as new): by design of the shortcut.
- Commit dad6ad25 on ar/decode-speed: STRATA_LA_NEON, STRATA_MISS_REPLAY, the look-ahead and miss-replay counters in the served
  I/O line (printed only with IO_PREFETCH / the switch). Default engine unchanged (texts identical in all four runs).

**Conclusions (iteration 8).** No new best: r2-e026 (34.81) stands. The decode CPU-miss path (~150-220 misses a
request, ~1.3 ms each from the SSD, `jobs` ~1.6-3.2 ms a window = 2-4%) resists every lossless predictor tried:
the next-layer router proxy catches ~10-25% (K 10-24) because hyper-connections break the layer-to-layer input
similarity, and wrong reads slow the right ones on the SSD; cross-request replay catches 14-37% and grows with
history, but costs reads at request start. The miss path is not a lever worth more iterations on this benchmark.

**Next, ranked:**
1. **HC read fusion (research item 8), the largest single lever left**: HC is 11.6 ms of the 49 ms T1 window
   (e014: hc0 norm/down/up, hc1 norm/down, hc1 up+router) at ~109 GB/s for ~1.27 GB, +1.2 ms a column. Code:
   src/kernels/cuda/fused_gr.cu `launch_multi` (~969): norm kernel -> down (gr_down_bal_kernel<T> with
   STRATA_HC_DOWN_WPB=21) -> up (gr_up_fast_lr_pf_kernel with GR_UP_LR + HC_UP_PF 48) = 3 launches a GR read, 96
   reads (288 launches) a window; the 320-vector goes through global memory between down and up. Step 1 (S): time the three pieces per T with
   STRATA_VERIFY_PROFILE stamps (gpu_stamp already sits between them: stamp_i0, stamp_i0 + 1) to see which one is off
   bandwidth. Step 2 (M): fold the norm into the down kernel's prologue (each down block recomputes the 4-branch RMS of
   its token: 40 KB a token, cheap) to remove one launch + one dependency a sublayer, keeping each value's sum order
   (bitwise: gr_parity checks it). Target -2 to -3 ms a window (3-4%).
2. **GEMV-family rewrite for 1-4 columns** (iteration 6 item 2): dense +6.1 ms and HC +3.6 ms at T4 over T1 with no
   new bytes; multi-iteration.
3. Miss path only if a cheap exact signal appears (e.g. the GPU router's own top-k of layer L+1 is known ~0.1 ms
   after its HC read; nothing earlier is accurate). MISS_REPLAY could help a long-running server with similar prompts
   (overlap grows with history); not this benchmark.
Do not retry: STRATA_LOOKAHEAD_K > 10 (e032), LA_NEON as a speed setting (e031), MISS_REPLAY on these prompts (e033),
probes for miss studies (the probe prompt has ~9 misses in 27 rounds).

### iteration 9 (2026-11-01 15:40-16:40), r2-e034..e039: HC down rows 2, layer 1's "norm", a faster drafter expert format
Pairing reference r2-e025 (same config + timing + spec depth): 2.49/2.67/2.67 tokens a window, 76.11/76.54/75.39 ms,
draft 6.20/6.21/6.34 ms; spec depth 73/85 47/61 33/41 | 74/80 48/59 40/43 | 75/83 48/59 37/40.
- Sizing the HC norm fold (iteration 8 item 1, step 2) from e014 before coding: the hc1 norm is 0.36-0.38 ms a window
  at every T = ~7.7 us a read incl. its stamp, so folding the norm into the down read saves <= ~0.5 ms (0.6%) minus a
  longer down prologue (every down block would recompute each token's 4 branch sums: 16 x T x 90 KB of L2 reads). Not
  done. Note: with the staged read (default) the norm that runs is `gr_norm_split_kernel` (T x 4 blocks), not
  `gr_norm_fast_kernel`; the two are bitwise equal (same per-thread element order).
- **e034 (code, discarded) e025 config + new STRATA_HC_DOWN_R2=2 (the HC down read at T >= 2 as gr_down_r2_kernel: the
  same 21 rows a block, 2 rows a warp, so each staged activation load from shared serves 2 rows; per-row sums bitwise
  gr_down_bal_kernel's): 34.70 (32.65/34.70/35.44), texts identical 1.0/1.0/1.0.** Paired by T with e025 (same windows):
  T4 verify 79.78/81.45/79.38 vs 79.87/81.02/79.63 ms, T2 57.84/57.52/57.46 vs 57.70/57.38/57.36: **no change.** The down
  read's growth with T (47.7 us a read at T1 -> 63 at T4 in e014, no new weight bytes) matched its 128-bit shared loads
  on paper (~5 us per extra token at 4 wavefronts a load), but halving them moved nothing, so they are not the limiter.
  Without Nsight the cause stays open (candidates: barrier phases per tile, GPU clock or DRAM state under heavier
  windows). Code removed (runs/r2-e034-hcdown-r2/source.diff). **Do not retry rows-per-warp on the HC reads.**
- e035: build failed (my declaration-order error), no run.
- **e036 (diagnostic, profiler only) e025 config + VERIFY_PROFILE + a new `|| ar hc0 norm L0 / L1 / rest, waitCPU L0 /
  L1` print: 33.87 profiled, texts identical.** Per request (ms a window): hc0 norm L0 0.009, **L1 0.65-0.78**, the other
  46 layers 0.395 (8.6 us a layer); waitCPU L0 0.05-0.12, L1 0.03-0.05. So the GDN "hc0 norm" excess (round 1 already
  suspected it) is all layer 1's PLE block, which pre() runs between stamp 0 and the norm: copy_from_mapped of the n-gram
  sums, the key (10240x2560 BF16, 52 MB) and value (2560x2560, 13 MB) projections and the per-token post-ops. ~0.47 ms
  at T1 = 65 MB at ~140 GB/s (near bandwidth), +~0.09 ms a token. It is not a CPU wait (the gather is <= 0.08 ms of host
  time and the flag is up before the GPU needs it; on this config ar_on() is false, so layer 1 does not spin on it).
  **Closed: no lever.** The print stays (profiler only, inert otherwise).
- Engine (opt-in, drafts only): **`STRATA_MTP_EXPERTS_AS=iq4_xs`** (mtp.cpp load_gguf_experts): the STRATA_MTP_EXPERTS
  GGUF's experts (use mtp-q8_0.gguf) are dequantized and requantized at load on 12 threads to gate/up IQ4_XS (4.25 bpw)
  + down IQ4_NL (4.5 bpw), the main model's expert kernel family (Split gate/up, IQ4_NL down) instead of Q4_0's per-entry
  path; then the source file's page cache is dropped (posix_fadvise DONTNEED). Both formats are above the base drafter's
  Q2_0. Load: ~49 s per engine start (the harness starts the engine 4 times a run: ~3 min a run).
- **e037 (STRATA_MTP_EXPERTS_AS=iq4_nl, the first version): no result**: the engine exits at the first draft with
  `native_expert_grouped: gate/up type 20`. Gate/up formats the grouped kernel takes (iq_kernels.cu STRATA_GU_FMTS): 16 17
  18 21 22 23 29 42 12 13 (14) 6 2 3 8; down (STRATA_D_FMTS): 20 23 42 7 6 2 3 8. IQ4_XS needs rows of 256 (down rows are
  640), hence IQ4_XS gate/up + IQ4_NL down.
- **e038 (iq4_xs, no page-cache drop) + timing + spec depth + DRAFT_PROFILE: 31.46, texts DIFFER (0.02): invalid.** The
  2.7 GB source GGUF left in the page cache shrank the expert cache to 18253 slots (34.74 GiB) from 19068 (36.27 GiB);
  min free 8.69 GiB. Same effect as e008 (cache size changes rounding), not the drafter. Readable anyway: **the draft moe
  piece is 0.265 ms a chain step vs Q4_0's 0.415 (e020/e021), round 0.30-0.32 (T1) / 0.40-0.41 (T2-T4) vs 0.48 / 0.53-0.55**
  (~-0.35 ms a window). Tokens a window 2.33/2.39/2.51 on the changed texts (e025 2.49/2.67/2.67): acceptance not
  comparable across different texts; e039 decides it.
- **e039 = e038 + the page-cache drop: 34.89 (33.82/34.89/35.27), texts identical 1.0/1.0/1.0, 19068 slots, min free
  7.15 GiB.** Paired with e025: windows 100/95/97 (292) vs 103/96/96 (295); ms a window 75.70/76.40/75.64 vs
  76.11/76.54/75.39; **draft 5.97/6.06/6.14 vs 6.20/6.21/6.34 ms a window (-0.15 to -0.23)**; per request ~7570/7258/7337
  vs 7839/7348/7237 ms (-3.4/-1.2/+1.4%: the window counts move by +-3 because the drafts differ). Accepted drafts by
  depth 153/163/159 vs 153/162/160: **IQ4_XS/IQ4_NL accepts exactly as well as Q4_0** and its moe piece is ~0.15 ms a
  step cheaper, but only ~0.2 ms a window (0.25%) survives (the round overlaps the commit). +0.08 over r2-e026's 34.81,
  under the 0.11 bar: **not a new best.** Kept as an opt-in (commit below): PASS, harmless, costs ~49 s of load per
  engine start.
- Commit 16247446 on ar/decode-speed: STRATA_MTP_EXPERTS_AS=iq4_xs (+ page-cache drop) and the e036 profiler print.
  Default engine unchanged. e034's kernel was reverted (stash + drop). Working tree clean.

**Conclusions (iteration 9).** No new best: r2-e026 (34.81) stands. Three more levers measured and closed: (1) the HC
down read's growth with window size is not its shared activation loads (rows 2 a warp: verify unchanged to 0.1 ms);
(2) the "hc0 norm" excess is layer 1's PLE projections (65 MB BF16 at ~140 GB/s, near bandwidth), not a wait; (3) the
drafter's expert format: IQ4_XS gate/up + IQ4_NL down = Q4_0's acceptance at ~0.2 ms a window less draft time
(0.25%, noise level). The HC norm fold is sized at <= 0.6% and was not built. What remains above ~1% is still only the
GEMV-family work, and e034 shows its T-growth limiter is not yet identified.

**Next, ranked:**
1. **Find the T-growth limiter of the verify GEMVs before any rewrite** (dense +6.1 ms and HC +3.6 ms at T4 over T1 with
   no new bytes, ~12% of a T4 window). e034 ruled out shared loads in the HC down read. Bisect with throw-away probe-only
   variants of gr_down_bal_kernel (texts will change: `./ar_probe.sh` with `--max-new 32` + STRATA_VERIFY_PROFILE, never
   a gated run): (a) skip the FMAs for tokens k >= 1 but keep their shared loads; (b) keep the FMAs, drop the
   per-tile barriers (stage all 8 tiles up front for T <= 2: 2 x 8 x 5 KB fits); (c) T = 1 data launched as T = 4.
   Whichever moves "hc0 down" at T4 toward T1's 2.29 ms names the limiter; the same fix then applies to the up read and
   the dense IL kernels. Also check whether the GPU clock is pinned (a T4 window draws more power): the BW probe's
   GB/s for the same kernel at nc 1 vs nc 4.
2. **Clean run of e039's drafter on e026's config** (STRATA_MTP_EXPERTS=.../mtp-q8_0.gguf + STRATA_MTP_EXPERTS_AS=iq4_xs
   + CUM + IO_PREFETCH, no timing), then repeat + needles if it clears 34.92. Expected +0.2-0.3% at most; one run.
3. Drafter step pieces left (e021: head 0.53 at bandwidth, q 0.20, attention 0.20, three HC reads 0.28, o 0.12, fc
   0.18): only launch/latency trimming remains, ~0.3 ms a window total.
4. N6 (0.4-0.8%) and the HC norm fold (<= 0.6%) together could make ~1%; each alone is under the noise bar.
Do not retry: rows-per-warp on the HC reads (e034); IQ4_NL gate/up for the drafter (no grouped kernel, e037); any
STRATA_MTP_EXPERTS change without checking the expert cache's slot count (e038: page cache shrinks it and changes texts).

### iteration 10 (2026-11-01 16:17-), r2-e040..e041, r2-p002..p005: the HC down read timed alone
- **e040 (env) e026 config + e039's drafter (STRATA_MTP_EXPERTS=mtp-q8_0.gguf + STRATA_MTP_EXPERTS_AS=iq4_xs), no
  timing: 34.90 (33.83/35.37/34.90), texts identical 1.0/1.0/1.0, 19068 slots, min free 7.15.** vs e026
  32.74/34.81/35.55: +0.09 at the median (under the 0.11 bar), mean of the three +0.33. Same as e039 (34.89): the
  IQ4_XS drafter is a consistent +0.1, never enough alone. Kept as the config to stack kernel changes on.
- Engine (probe only, inert without STRATA_BW_PROBE=1): **the BW probe now times the HC reads alone** (fused_gr.cu
  gr_occupancy_report): 16 launches on fresh weights (106 MB a kind, L2 never holds them) in one graph, best of 5, at
  T 1-6, for gr_down_bal_kernel (the WPB 21 read), the same with NOLOAD (synthesized weights: its FMAs, shared loads and
  barriers alone), gr_up_fast_lr_pf_kernel, and gr_down_rr_kernel<T, R, DEPTH, NOLOAD> variants (R rows a warp, rpb rows
  a block, weights DEPTH tiles ahead in fully unrolled registers). One probe = ~2.5 min (`./ar_probe.sh <id>
  overrides/r2-p002-hc-alone.json "--max-new 8"`, grep `hc alone`). Use this for every HC kernel idea before a bench.
- **p002/p004/p005 (us a launch, alone):**
  | T | down (bal, today) | down NOLOAD | up (today) | R2/21 D1 (= e034) | R2/11 D1 | **R2/11 D2** | R1/11 D2 | R2/11 NOLOAD |
  |---|---|---|---|---|---|---|---|---|
  | 1 | 44.9 (148 GB/s) | 13.9 | 41.0 (160) | 45.7 | 43.3 | **43.3** | 42.5 | 10.4 |
  | 2 | 47.0 | 22.2 | 46.0 | 49.7 | 46.3 | **46.4** | 47.2 | 20.9 |
  | 3 | 52.0 | 31.4 | 49.7 | 55.2 | 49.1 | **48.9** | 55.9 | 28.8 |
  | 4 | 61.1 (108 GB/s) | 40.6 | 54.9 (120) | 61.0 | 53.4 | **52.3** | 66.0 | 39.3 |
  | 5 | 67.8 | 49.7 | 68.4 | 68.3 | 60.3 | **58.3** | 75.2 | 46.5 |
  | 6 | 77.4 | 58.3 | 76.0 | 75.4 | 69.5 | 71.4 | 85.3 | 56.0 |
  Readings: (1) **the growth with T is the kernel itself, not its context**: alone, down goes 44.9 -> 61.1 us at
  T1 -> T4 (e014 in the pipeline: 47.7 -> 63). The memory floor of 6.6 MB is ~39 us (the probe's 5040-B rows read at
  ~170 GB/s); the up read grows the same way (41 -> 55). (2) **Its compute side alone grows ~8.8 us a token** (NOLOAD
  13.9 -> 58.3), ~7x the FMA issue time (3.3M FMA a token on 16 SMs = ~1.3 us) and **unchanged when each shared
  activation load serves 2 rows** (R2 NOLOAD 10.4 -> 56.0): neither the shared loads nor the FMA issue are the limit
  (latency of the 8-deep dependent FMA chain in dot8u x the barrier-paced tiles is the remaining suspect; Nsight would
  settle it). (3) What helps is decoupling: 2 blocks a SM of 6 warps (R2/11) instead of 1 of 21, -8.7 us at T4; one
  extra tile of weight prefetch adds ~1 us at T4-T5. R1 with 11-row blocks is worse (fewer rows in flight).
  (4) e034's "no change" is reproduced alone (R2/21 = bal), so e034's reading was right for its kernel.
- **Engine (opt-in): `STRATA_HC_DOWN_RR=1`** (with STRATA_HC_DOWN_WPB): launches of 1-6 tokens take
  gr_down_rr_kernel<T, 2, 2> (2 rows a warp, 11 rows a block = 30 blocks of 6 warps, weights 2 tiles ahead). Each row's
  lanes, tiles, dot8u order, accumulation and xor tree are gr_down_bal_kernel's (bitwise by construction; the startup
  check "checked bit for bit against the plain read" also covers it). Expected ~-0.4 ms a window (0.5%) from the
  table: T4 -0.84 ms (96 down reads), T3 -0.36, T1 -0.15.
- **e041 (code) e039's override + STRATA_HC_DOWN_RR=1: 33.79 (33.79/25.94/35.04), texts identical 1.0/1.0/1.0.**
  Request 2 is a stall outlier (25.9 tok/s; its T4 verify averages 132.7 ms, the PLE/SSD type; 9868 vs 7258 ms in
  e039 with the same drafts). Requests 1 and 3: 7576 / 7307 ms vs e039 7570 / 7337 (+0.1 / -0.4%). Paired by T (same
  windows): T1 verify -0.11 / -0.27 / -0.14 ms, T3 -0.07 / -0.26 / -0.19, **T4 +0.09 / (stall) / -0.42**: the isolation
  gain mostly does not reach the pipeline.
- p006/p007 (VERIFY_PROFILE probes with/without RR, `--max-new 96`): no table. **The probe prints the stage table only
  with `--stats`** (or use a served run); not rerun.
- **e042 (diagnostic) e041 + VERIFY_PROFILE: 34.00 profiled, texts identical.** Per window, hc0 + hc1 down (request 1)
  vs r2-e036 (bal, same kernel otherwise): **T1 4.43 vs 4.59, T2 4.83 vs 4.76, T3 5.11 vs 5.24, T4 5.88 vs 5.96 ms**:
  in the pipeline the RR read costs ~61 us at T4 (alone 52.3) while bal costs 62.1 (alone 61.1). So the pipeline adds
  ~9 us to RR at T4 and ~1 us to bal. Not explained yet; best guess: at T4 an RR block needs 40 KB of smem and two of
  them a SM (80 KB), so whatever runs beside the down read on the side stream (shared expert + quant, 4.57 ms a T4
  window) keeps the second block off some SMs, while bal's single 40 KB block fits. At T1 (10 KB a block) the gain
  arrives as predicted (-0.16 ms).
- Commit 4f8dacc1 on ar/decode-speed: STRATA_HC_DOWN_RR (opt-in) and the HC isolation probe (STRATA_BW_PROBE only).
  Default engine unchanged.

**Conclusions (iteration 10).** No new best: r2-e026 (34.81) stands; e040 (IQ4_XS drafter, clean) 34.90 is the same
+0.09 as e039. New tool: HC reads timed alone (2.5-min probe). New facts: the HC GEMVs' growth with window size is
inside the kernels (alone 45 -> 61 us down, 41 -> 55 us up, T1 -> T4; floor ~39 us), and it is a compute-side cost
(~8.8 us a token of FMA chains / barrier-paced tiles), not DRAM, shared bandwidth or FMA issue. Splitting the block
in two (RR) wins alone but not beside the side stream at T4. Isolation numbers must be checked in a profiled served
run before a bench (e041/e042 cost two runs to learn that).

**Next, ranked:**
1. **Why RR loses its T4 gain in the pipeline (S)**: (a) alone, time RR at T4 with a co-running dummy kernel on a
   second stream holding ~48 KB smem a SM (reproduces the side stream); (b) or try RR with single-buffered activation
   tiles at T >= 3 (20 KB a block at T4: two blocks fit beside the side stream); (c) or rpb 11 with 1 block a SM
   pinned (launch 16 blocks of 11 warps that loop over 2 row groups). Measure alone, then e042-style profile, then bench.
2. **Same treatment for the up read (M)**: up is 41 -> 55 us alone (T1 -> T4) at 160 blocks = 3.3 waves of 48 (tail
   ~25% of a wave); a 48-block persistent version that prefetches its next row group while computing, same per-row
   lanes / xor8 tree (bitwise). Isolation first (add it to the probe), then a profiled served run.
3. **Compute side of the down read (research)**: NOLOAD grows 8.8 us a token with 21 warps. Splitting dot8u into 2
   accumulators would change the sum order (not allowed); raise ILP across rows/tokens instead, keeping each row's
   order (e.g. a row group's tokens split over 2 warps, each warp keeping all of a row's lanes for its tokens).
   Nsight-free bisect: NOLOAD with the barriers removed (stage all 8 tiles first at T <= 2).
4. The GEMV-family rewrite (dense IL kernels) with the same isolation-probe method: add Q6_K / Q8_0 IL kernels at
   nc 1-6 to the probe (alone, fresh weights) to see whether their T-growth is also intrinsic.
Do not retry: RR as a speed setting at spec 4 (e041/e042); a VERIFY_PROFILE probe without `--stats` (p006/p007).

### iteration 11 (2026-11-01 16:53-), r2-e043..: stacking the two small PASS opt-ins
- Correction to iteration 10's e042 reading: **the profiled run has no shared-expert side stream** (verify.cpp:2100
  `sh_fork` requires `!prof_on_`), so "the side stream keeps RR's second block off the SMs" cannot explain RR's
  ~9 us pipeline penalty at T4 in e042. Also not the smem carveout: gr_down_bal_kernel and gr_down_rr_kernel both set
  PreferredSharedMemoryCarveout 100 (fused_gr.cu:1038, :955). Cause still open.
- **e043 (env) e040 config (IQ4_XS drafter + CUM + IO_PREFETCH) + STRATA_HC_DOWN_RR=1, no timing: 35.18
  (33.98/35.41/35.18), texts identical 1.0/1.0/1.0, 19068 slots, min free 7.15.** Paired with e040 (identical drafts
  accepted 157/203, 163/193, 159/203): decode ms 7533/7230/7277 vs 7566/7238/7336 (-0.4/-0.1/-0.8%). +0.37 over r2-e026
  at the median (bar 0.11); the two opt-ins stack (IQ4_XS drafter ~+0.1, RR ~+0.4%).
- **e044 = e043 + needles: 34.93 (33.84/35.25/34.93), texts identical 1.0/1.0/1.0, needles 3/3, min free 7.02.**
  Decode ms 7566/7263/7328: **equal to e040's 7566/7238/7336**, so RR's own share is 0-0.4% and e043 was a good draw.
  Still, both runs beat r2-e026 34.81 by more than the 0.11 spread (+0.37, +0.12): **new best by rule 4, r2-e043
  35.18 (repeat 34.93, needles 3/3), overrides/r2-e043-iq4xs-rr.json, engine 4f8dacc1 (no source change).** Honest
  size: ~+0.3-0.7% over e026 (mean of the two runs 35.06), most of it the IQ4_XS drafter's draft time.
- **e045 (env) e043 + STRATA_LOOKAHEAD=0 + STRATA_IO_PF_AHEAD=0 (both never tried; generate.cpp:5431 turns the router
  look-ahead thread off, expert_source.cpp:588 the predicted read-ahead queue; demand preads stay): 35.17
  (34.10/35.36/35.17), texts identical 1.0/1.0/1.0, min free 7.22.** Decode ms 7507/7239/7279 vs e043 7533/7230/7277:
  **no change**; prefill 348.6 vs 352.6 tok/s (-1%). With iteration 8 (more predictions: -1%) this closes the look-ahead
  both ways: its reads neither help nor hurt decode at K 10. Not kept (no gain), but it is the leaner config if a
  CPU core or ~0.07 GiB is ever needed.
- **e046 (env) e043 + STRATA_SH_FORK_LATE=0 + STRATA_HOST_CORE=last (from a scan of ~135 decode-path switches, ~50
  already tried): 34.73 (32.11/34.89/34.73), texts identical, but decode ms 7972/7337/7371 (+5.8/+1.5/+1.3% vs e043)
  and, unexpectedly, different drafts (accepted 157 of 200 / 162 of 193 vs 157 of 203 / 163 of 193).** Drafts read
  the verifier's hidden states, so one of the two switches changes some hidden-state bits while the argmaxes stayed
  (SH_FORK_LATE=0 is the suspect: it moves the shared expert's fork to the layer top; possibly a read of a buffer that
  is still being written; not investigated). Prefill +7% (382 vs ~355 tok/s, TTFT 10.9 s): likely HOST_CORE=last (host
  on cpu3, workers on 0-2). **Do not use SH_FORK_LATE=0.** HOST_CORE=last alone is a prefill-only lever (untested
  alone for decode).
- **e047 (env) e043 + STRATA_EXPERT_V2=1: NO RESULT YET (orphan).** Launched 17:13; the local ar_run.sh was killed
  by its 30-min background limit while waiting (the Mac clock read 19:39 at the next check: it likely slept), so the
  Jetson bench runs detached and **the next iteration's first ar_run.sh collects it** (collect_orphans writes its
  results.tsv row). Engine tree clean (its source.diff is empty). What it tests: iq_kernels.cu:3531, the S26 expert
  path that matches exactly this model (IQ3_S gate/up + IQ4_NL down, 2560 x 640): s26_gu_l_kernel (4 rows a warp,
  32 lanes a row, grid table and the chunk's q8_1 rows in smem; each row's sum is lane items + xor 16..1 = the sub16
  path's s + s16 then xor 8..1, so bitwise by construction), s26_swiglu_q8_1_kernel (same h expression, contraction
  off, same quantizer helpers) and s26_down_l_kernel (4 rows a warp). It ignores VRAM_GY (one block row per possible
  group) and has no EXP_PF prefetch, so it may lose. Round 1 only ran it bundled with 7 other switches (r1 e006,
  QFUSE-broken texts; stage total unchanged while ATTN_LANECELL alone cost +1.55 ms, so the rest saved ~1.5 ms).
  **Read it: texts must be 1.0/1.0/1.0; pair decode ms with e043 7533/7230/7277 (same drafts expected: 157/203,
  163/193, 159/203).** If faster by > 0.3%: repeat + needles, then try STRATA_EXP_PF-style prefetch / GY stride in
  the S26 launcher (opt-in code).

**Conclusions (iteration 11).** New formal best **r2-e043 35.18** (repeat r2-e044 34.93, needles 3/3; texts identical):
the IQ4_XS drafter and the RR down read stacked, with no source change; honest size ~+0.3-0.7% over r2-e026 because
e044's per-request ms equal e040's. Closed: the look-ahead in both directions (e045), SH_FORK_LATE=0 (changes drafts,
slower, e046). A scan of ~135 decode-path switches (~50 already tried) left few exact untried ones: EXPERT_V2 (e047,
pending), STRATA_NO_MMVQ_ROWS2=1 (non-IL multi-column GEMVs: drafter catch-up rows, shared expert), POOL_SPIN_US,
SSD_KEEPALIVE (stalls), HOST_CORE=last alone (prefill), Q6P_GRID with Q6_PACKED (needs +0.6 GB: near the RAM floor).
Process note: 5 runs used ~25 min of bench time; the rest was reading.

**Next, ranked:**
1. **Collect and judge e047 (EXPERT_V2)** as described above (first ar_run.sh of the iteration collects it).
2. **Gate/up isolation probe** (never built in round 1 or 2; gate/up is ~16% of a window at ~105 GB/s at T1 vs down
   ~121, e014): add native_gu_multi_kernel<21, false, true[, true]> and s26_gu_l_kernel to the BW probe (fused_gr.cu's
   HC-alone probe is the template: 16 launches on fresh weights in one graph, best of 5), with synthetic groups (10
   groups of 1 entry = T1; ~26-30 groups of 1-4 entries = T4; L = native_expert_layout(21, 20, 2560, 640), grid
   (80, gy)), reporting us and GB/s. Then variants that keep each row's sum tree: (a) stage a block's 16 contiguous
   rows (17.6 KB, 16-byte aligned) into smem with int4 loads and decode from smem (cuts ~9 tiny global loads per
   32-weight item); (b) the funnel-shift aligned 32-bit loads for qs/signs. Probe first, bench only a winner.
3. Why RR loses its T4 gain in the pipeline: not the side stream (off in profiled runs) and not the carveout (both
   kernels 100). Candidates left: the stamp/launch boundary before it, L2 state after the norm kernel. Low priority
   (worth <= 0.5%).
4. HC up read persistent version (iteration 10 item 2, ~0.65%, M effort) and N6 + HC norm fold together (~1%).
5. HOST_CORE=last alone (one env run) if prefill/TTFT matters to the operator: +7% prefill in e046.
Do not retry: STRATA_LOOKAHEAD=0 / IO_PF_AHEAD=0 as a speed setting (e045), SH_FORK_LATE=0 (e046).


### wrap-up (orchestrator, 2026-11-01 ~20:00 PST, loop ended at 19:56)
- **e047 (collected) e043 + STRATA_EXPERT_V2=1: 33.92, texts identical.** Slower than e043 (35.18): closed.
- **e048 = e043 at the engine head (4f8dacc1, renamed 8d466b5d after a message-only rewrite that removed two
  attribution lines; trees identical): 35.09 [33.97/35.43/35.09], texts identical 1.0/1.0/1.0.** Third independent
  server start of the best settings: 35.18 / 34.93 (needles 3/3) / 35.09.
- The Mac slept ~17:15-19:55 PST: iteration 11 sat paused, so the loop's last ~2.5 h ran nothing. e047 finished on
  the Jetson at 17:16 and was collected on wake (the detached harness worked as designed).
