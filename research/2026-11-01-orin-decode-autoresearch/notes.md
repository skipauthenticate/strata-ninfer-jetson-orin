# Autoresearch notes

**Leading candidate (iteration 20): e096 / e098 (repeat, needles 3/3) — decode_med 34.40 / 34.31** (e099, the same
build + an inert-in-effect router prefetch, 34.38), commit **0613c7a2** (ar/decode-speed: + opt-in STRATA_HC_DOWN_WPB,
STRATA_HC_UP_PF; head 3f76f45d adds profiler-only stamps), overrides/e096-hcup-pf48.json (= e090's file +
STRATA_HC_DOWN_WPB=21 + STRATA_HC_UP_PF=48), **PASS** (bitwise by construction + drafting policy; texts = e015
1.0/1.0/1.0 in e095-e100). +1.72 / +1.63 over e086's 32.68: the repeat does not clear the 1.7 bar, so e086/e087 stays
the formal best; >= 34.39 on a repeat clears it. Per request vs e087: 7783 / 7461 / 7225 ms per 256 tokens (e098) vs
7831 / 7860 / 7836 = -0.6 / -5.1 / -7.8%.
**Leading candidate (iteration 18): e092 (repeat of e090, needles 3/3) — decode_med 34.09** (e090: 32.68 with a
CPU-expert stall in request 2; stall-free ~34.6), commit **93c74af5** unchanged, overrides/e090-hnorm-stream.json
(= e086's file + `--mtp-hnorm stream`), **PASS** (drafting policy only; texts = e015 1.0/1.0/1.0 in e090, e092, e093).
Per request vs e087: 0.0 / -4.5 / -7.2% (requests 1 and 3 reproduce across e090/e092 within 0.03 ms/window). +1.41
over e086's 32.68: below the 1.7 bar, so e086/e087 stays the formal best. >= 34.39 clears it.
**Current best (iteration 17): e086 / e087 (repeat, needles 3/3) — decode_med 32.68 / 32.67**, commit **93c74af5**
(ar/decode-speed head: + opt-in STRATA_EXP_PF=1), overrides/e086-exp-pf.json (= e077's file + STRATA_EXP_PF=1),
**PASS** (an L2 prefetch hint only: the kernels' loads, values and order are unchanged; texts = e015 1.0/1.0/1.0 in
e086, e087, e089). +1.74 / +1.73 over e059's 30.94 (> the 1.7 bar; vs e060's 30.98: +1.70 / +1.69, a thin margin),
repeat confirmed (paired windows within 0.03 ms). Paired vs e080: -0.35 to -0.39 ms/window; vs e077: -0.42 to -0.56.
+7.8 over the baseline median 24.88. Formal best before it: e059 / e060 (30.94 / 30.98), commit c6f7ca32.

Iteration 16 (e081-e085): no new candidate; all three arms bitwise but neutral or slower. Leading candidate stays
e077/e080 below, formal best stays e059/e060. Current profiled stage table: e085 (iteration-16 log).
Leading candidate (iteration 15): **e077 / e080 (repeat, needles 3/3) — decode_med 32.46 / 32.52**, commit
**07c4d793** (ar/decode-speed head: + opt-in STRATA_ATTN_PRE75=1 on CUDA), overrides/e077-attn-pre75.json (= e074's
file + STRATA_ATTN_PRE75=1), **PASS** (bitwise by construction: PR #540's kernel, see the iteration-15 log; texts =
e015 1.0/1.0/1.0 in e077-e080). Paired vs e076: -1.8 to -2.1 ms/window. +1.52 / +1.54 over e059/e060: below the
1.7 bar, so e059/e060 stays the formal best; >= 32.65 clears it (~-0.4 ms/window more at the same windows).
Leading candidate (iteration 14): **e074 / e076 (repeat, needles 3/3) — decode_med 31.77 / 31.69**, commit
**c65c86ee** (ar/decode-speed head: + opt-in STRATA_HIT_COMBINE), overrides/e074-hitcomb.json (= e067's file +
STRATA_HIT_COMBINE=1), **PASS** (bitwise by construction: the combine reads 0.0f + hit with the non-ftz add the old
add_hits_kernel did, and the CPU rows as copied; texts = e015 1.0/1.0/1.0 in e074-e076). Paired vs e070: -0.2
ms/window. +0.83 / +0.71 over e059/e060: below the 1.7 bar, so e059/e060 stays the formal best; >= 32.65 clears it.
Leading candidate (iteration 13): **e067 / e070 (repeat, needles 3/3) — decode_med 31.69 / 31.60**, commit
**108bd50f** (ar/decode-speed head: + opt-in STRATA_NO_PCIE, Q8_0 1-column warp kernel at 40 registers),
overrides/e067-nopcie-q8lb.json (= e065's file + STRATA_NO_PCIE=1), **PASS** (launch removal + a register cap; the
PCIe share is 0.00 in every window even at 32K, so no placement moves; texts = e015 1.0/1.0/1.0 in e067-e071).
Paired vs e065: -0.84 ms/window (mean of e067/e070). +0.75 / +0.66 over e059/e060: below the 1.7 bar, so e059/e060
stays the formal best; >= 32.65 clears it (~-2.4 ms/window more at the same windows).
Leading candidate (iteration 12): **e065 / e066 (repeat, needles 3/3) — decode_med 31.31 / 31.38**, commit
**2e7a8bdf** (ar/decode-speed head: + opt-in STRATA_GR_UP_LR, STRATA_MMVQ1_WARP), overrides/e065-mmvq1-warp.json
(= e059's file + STRATA_GR_UP_LR=1 + STRATA_MMVQ1_WARP=1), **PASS** (bitwise by construction; texts = e015
1.0/1.0/1.0 in e063-e066). Paired vs e059: -0.64 to -0.93 ms/window. +0.37 / +0.40 over e059/e060: below the 1.7
bar, so e059/e060 stays the formal best; ~+1.3 more (>= 32.65) clears it.
Current best (iteration 11): **e059 / e060 (repeat, needles 3/3) — decode_med 30.94 / 30.98**, commit **c6f7ca32**
(ar/decode-speed head: opt-in STRATA_VRAM_GY), overrides/e059-vram-gy8.json (= e044's file + STRATA_VRAM_GY=8),
**PASS** (bitwise by construction: group stride only; texts = e015 1.0/1.0/1.0 in e058-e060). +1.74 / +1.78 over
e031's 29.20 (> the 1.7 bar), repeat confirmed. Paired vs e053: -1.18 to -1.41 ms/window. +6.1 over the baseline
median 24.88. Formal best before it: e031 / e033 (29.20 / 29.14), commit 9b87a9c0.
Leading candidate (iteration 10): e053 / e054 (repeat, needles 3/3) — decode_med 30.47 / 30.38 (e051, same
rows-1 cap + a neutral rows-2 cap: 30.50), commit cda89788, overrides/e044-q6il-noi2f-clk.json
(= e021's file + the inert STRATA_BW_PROBE=1), **PASS** (bitwise by construction; texts = e015 1.0/1.0/1.0 in e050-e054).
Paired vs e048: -1.76 to -2.05 ms/window; vs e031 -3.4 to -3.6. +1.27 over e031's 29.20: still below the 1.7 bar,
so e031/e033 stays the formal best; ~+0.45 more (>= 30.91) clears it.
Previous leading candidate (iteration 9): e047 / e048 (repeat, needles 3/3) — decode_med 29.76 / 29.77, commit
241e3e25, overrides/e021-pin-grfast-dvocab40k-q6il.json (e044's file = the same + the inert
STRATA_BW_PROBE=1), **PASS** (bitwise by construction; texts = e015 1.0/1.0/1.0 in e043-e048). Paired vs e031:
-1.56 to -1.70 ms/window (-1.9%). +0.57 over e031: below the 1.7 bar, so e031/e033 stays the formal best. Three
bitwise kernel cuts on top of 9b87a9c0: Q6_K IL dot without __vsubss4/I2F, IQ3_S signs without __vcmpne4/__vsub4,
gate/up kernel capped at 48 registers.
Current best: **e031 / e033 (repeat, needles 3/3) — decode_med 29.20 / 29.14**, commit **9b87a9c0** (branch
ar/decode-speed: gr_up_fast_kernel reads activations once for both rows; branch head 59190a06 = the same decode path +
the inert opt-in STRATA_BW_PROBE diagnostic, extended in iteration 8), overrides/e021-pin-grfast-dvocab40k-q6il.json,
**PASS** (bitwise: texts = e015 1.0/1.0/1.0 in both runs). +1.85 / +1.79 over e015 (> the 1.7 bar), +4.3 over the
baseline median 24.88. Paired vs the same overrides without the kernel change: -1.3 to -1.45 ms per verify window.
Previous best: e015 / e016 (repeat) — decode_med 27.35 / 27.36, commit f5130eb5 (no source change),
overrides/e015-pin14629-grfast.json = `--kv-grow --expert-cache 14629` + env STRATA_GR_FAST=1, **PASS**
(placement + a kernel whose output is bitwise the default's: e015 texts = e007 1.0/1.0/1.0, e016 = e015 1.0/1.0/1.0),
needles 3/3 (e016). +2.47 over the baseline median of medians 24.88 (> the 1.68 spread), repeat confirmed.
Leading candidate (iteration 4): e021 — decode_med 28.76, commit 4a569815 (adds the opt-in), overrides/
e021-pin-grfast-dvocab40k-q6il.json = e015 + env STRATA_DRAFT_VOCAB_TOP=40960 + STRATA_MMVQ_IL_ROWS (Q6_K), **PASS**
(texts = e015 1.0/1.0/1.0, needles 3/3). +1.41 over e015 (< 1.7, so not yet the formal best; needs a repeat or one
more gain on top). Paired -4.1 to -4.6 ms/window vs e015. Iteration 5: e026 (e021 + a bitwise IL-rows variant)
decoded 28.76 again with the same texts and windows, so e021's level reproduces; it is still +1.41, below the bar.
Baseline (runs/baseline-1..3): 24.48 / 24.88 / 26.16. Target 45.0 is not in reach with switches (see iteration 3).
**RETRACTED: e003/e004 "exact stack" is NOT lossless.** STRATA_QFUSE=1 corrupts output on CUDA (iteration 2 below).
Never put STRATA_QFUSE in an arm without the fix.

## Log (newest last)
- bootstrap: warm profile captured by runs/warmup-profile (adaptive tier on), then base-overrides.json fixes every run
  to it with --adapt-every 100000. Before tonight the installed config (adaptive on) decoded 23.7 tok/s.

### iteration 1 (2026-11-01 ~02:05-02:30)
- **The gate cannot PASS anything yet: the baselines disagree with each other** (baseline_self_min 0.023;
  baseline-2 vs -1: 0.10/0.13/0.18). Cause (likely): `--expert-cache auto` sizes from free RAM, so slots vary run to run
  (18362 / 17913 / 18310 / 18155) and the experts at the boundary go GPU vs CPU/PCIe, which round differently. e001 got
  1.0 on 2 of 3 prompts vs some baseline, so the engine itself is deterministic given a placement. Fix for the gate:
  pin `--expert-cache N` (a byte budget of N largest 2.66 MB blobs; auto picked 14093 -> 18362 sized slots) and take
  new baselines with it (needs the operator: run ids must be e/p, compare.py only reads runs/baseline-*).
- **Probes return no engine output**: runs/p001-stats/probe.txt is only the memory-guard JSON (status pass, 58 s);
  the engine's stdout (--stats tables) is not copied back. Harness fix for the operator (probe.sh on the Jetson).
  Workaround used: env `STRATA_DECODE_TIMING=1` (+ `STRATA_VERIFY_PROFILE=1`) makes the server print a per-request
  decode breakdown and GPU stage table to stderr = runs/<exp>/engine.log.
- Arithmetic from baseline-1 engine.log: 256 tokens, 233 drafts offered, 148 accepted -> 108 windows, avg T 3.2,
  ~96 ms per window (39 ms/token). Decode hit rate is already 99.7% (the cache holds 18.3K of 24.6K pairs but the
  warm profile covers what this prompt routes), so the miss path is NOT the bottleneck at 4K prompts.
- e001-devplan `STRATA_VERIFY_DEVICE_PLAN=1` (verify.cpp E-6: a layer-group whose routed experts are all resident is
  planned on the GPU, which then skips its flagA/flagB/CPU waits; same kernels, exact): 25.18 (24.27-25.90), gate
  0.54 (1.0, 0.54, 1.0) = REVIEW by the rule but no different from baseline noise. **No gain**: the per-layer host
  doorbell is not on the critical path; the GPU is busy for most of the 96 ms window. Not kept.

- e002-diag (base + `STRATA_DECODE_TIMING=1 STRATA_VERIFY_PROFILE=1`; a measurement, not an arm; 24.24 med, one
  request hit a 111 ms/window QSA waitA stall -> 11.3 tok/s, probably the shared Jetson). Per request:
  `113 windows, avg T 2.94, 2.27 tokens/window, 93.5 ms/window = verify 84.1 (GPU-reach wait 72.3 + per-layer host
  5.1) + draft 9.3`. CPU misses 0.10-0.15 distinct experts per layer-window. **GPU stage table, ms/window (GDN+QSA):**
  routed experts "VRAM hits" 17.5+5.4 = **22.9** (~2.8 GB/window -> ~120 GB/s, near Orin's practical bandwidth);
  dense GEMVs (qkv 7.5, z 4.2, out-proj 5.1+1.8, q+q-idx 3.1) = **21.6**; hyper-connection reads: hc-read1+router
  7.1+2.4 and hc0 norm/down/up 6.5+1.9 = **17.8**; head 5.4; shared+quant 4.0; attention+scores 4.2; waitCPU 2.9;
  rec/ab/conv 2.0. Total GPU 84 ms + MTP draft ~9.5 ms (host-timed, ~4.5 ms per draft step).
  -> 45 tok/s at 2.3-2.4 tokens/window needs <= ~53 ms/window: no single knob gets there. The HC reads (17.8 ms for
  tiny tensors) and the dense GEMVs look latency/launch-bound on Orin's 16 SMs, the experts are near bandwidth.
- Notes on switches read in verify.cpp: `STRATA_LFUSE` needs a 100%-resident cache (ar_on), so it is inert here;
  `--spec-split` (two token groups) is already off by default; `STRATA_HC_SPLIT` 0/1/2 picks plain/split/staged HC
  reads, all checked bit for bit on the card at start (staged is chosen now; tuned on an RTX 4080, untested on Orin);
  `STRATA_SH_STREAM=0` runs the shared expert on the main stream (fork on by default on CUDA; same kernels).
  `--mtp-q4` would cut draft time but lowers drafter weight precision: rule 1 reads as forbidding it, ask the morning
  review before trying.

- e003-exact-stack (`--kv-grow` + DEVICE_PLAN + QFUSE + QDEDUP, all exact by their source comments):
  **26.45** (13.26-27.70), and e004 rerun **26.52** (26.02-27.55). Gate 0.023 vs baselines (REVIEW, uninformative);
  e004 vs e003: 0.56/0.94/0.83 (slots 19092 vs 19107: kv-grow is still auto-sized, so placement drifts again).
  kv-grow works on Orin: "elastic K/V: 16384 of 262144 cells (0.25 of 3.35 GiB)", cache 19.1K slots / 36.3 GiB
  (vs ~18.2K / 34.9), min free RAM **8.7 GiB** (vs ~7.0: more headroom, not less). **Prefill 281-290 tok/s vs 237,
  TTFT 14.2-14.6 s vs 17.3** (more slots = fewer SSD expert reads in the prompt). Clean requests: 83-92 ms/window.
  **Verdict: ~+5% decode over the baseline mean (25.2), not > the 1.68 spread -> not counted as better.** Not
  committed (overrides only). Worth keeping in the base for TTFT if the operator agrees; at long contexts kv-grow
  gives slots back as the K/V fills, so the 4K numbers hold for short contexts only.
- **Per-request stalls**: ~1 in 3 requests decodes at 9-16 tok/s (baseline-2 min 9.11, baseline-3 16.57, e002
  11.31, e003 13.26). e003's stalled request shows `stage 98.46 ms/window` = the PLE row gather (direct SSD reads of
  the n-gram table, verify.cpp run() k==0) taking ~100 ms per window for the whole request; e002's shows a 111 ms
  QSA `waitA` (GPU waiting on the host's flag). SSD contention (the prompt reads ~16 GB of experts through mmap per
  request, misses fault on the same SSD) or another tenant. The median hides it; a fix would raise decode_min.

### iteration 2 (2026-11-01 ~02:22-02:40), e005-e010
- **Read the texts, not only agreement_min.** Baselines (and e001, e002, e007, e009) are clean prose; their 0.023
  agreement is a near-tie at word 4 ("presents" vs "represents"), not corruption. e003/e004/e005/e006/e008 are
  visibly broken: dropped words and repeats ("This structure.\n\n###", "This property. This property.",
  "if one-way if one-way if one-way", "transformation**ential generator"). Bisection: e007 kv-grow alone = clean;
  e008 QFUSE alone = broken. **STRATA_QFUSE=1 is the corrupter.**
- **Root cause (read in verify.cpp):** record_window disables the one-token self-commit under QFUSE
  (verify.cpp:1390 `self_commit = T == 1 && ... && !g_qfuse() && one_token_self_commit()`), but Verifier::commit
  (verify.cpp:3630) skips the commit graph when `last_t_ == 1 && one_token_self_commit()`, with no QFUSE check. So
  every 1-token window advances neither the GDN state nor its conv history: the recurrent state loses that token.
  HIP's one_token_self_commit() is always false, so both sides launch the commit graph there: that is why QFUSE was
  exact on Strix Halo. Fix (one line, in runs/e010-kvgrow-qfuse-fixed/source.diff): `&& !g_qfuse()` inside
  one_token_self_commit()'s lambda. **e010 (kv-grow + QFUSE + fix): texts clean again**, but not bitwise vs e007
  (0.10/0.023/0.13) and **25.98 tok/s, 0.6 slower than kv-grow alone** -> not kept, source reverted. Upstream should
  get the fix anyway; any S26 stack on CUDA is broken without it. QDEDUP not tested alone: it is inert while the
  shared expert forks onto its own stream (the default), and VERIFY_PROFILE turns that fork off (verify.cpp:255), so
  profiled runs switch QDEDUP on. Keep QDEDUP out of profiled arms.
- **e007 kv-grow only: 26.58 (26.49-26.62); e009 kv-grow + SH_STREAM=0: 26.55 (26.46-26.60).** e009 vs e007 texts
  **1.0 / 1.0 / 1.0** (slots 19063 vs 19068). So (a) kv-grow auto runs reproduce exactly, and **e007 works as a text
  reference for kv-grow arms**: `python3 compare.py runs/<exp>/result.json runs/e007-kvgrow-only/result.json`, where 1.0
  means the same arithmetic. No pinned cache needed for that. (b) SH_STREAM=0 is bitwise the same with no speed
  effect on Orin: drop it. Mechanism of the kv-grow gain: CPU experts 0.02-0.06 per layer-window (base 0.10-0.15),
  per-layer host 1.1-2.5 ms/window (base 5.1-6.3); ms/window 90-97 at 2.4-2.6 tokens/window. **No stall request in
  9 kv-grow requests** (e007/e009/e010 min 25.87), against ~1 in 3 in the baselines: the extra ~1-1.7 GiB of free RAM (min avail 8.7-8.8 vs 7.0-7.9 GiB)
  probably keeps the PLE rows in the page cache. Not proven.
- e005 `--expert-cache 14000` (a budget of 14000 largest blobs -> 18241 slots) + VERIFY_PROFILE: broken texts (QFUSE
  was in it), 23.62. e006 = e005 + the gfx1151 arch table's exact decode switches (arch_defaults.cpp: Q8_PACKED,
  Q6_PACKED, MMVF_ROWS, ATTN_LANECELL, EXPERT_V2, TSUM, GDN_SPLIT, PLE_BATCH): **stage total 84.93 vs 84.93
  ms/window, no gain**. ATTN_LANECELL makes QSA attention slower (5.14 vs 3.59 ms). EXPERT_V2 only matches
  IQ3_S gate/up + IQ4_NL down at 2560x640 and changed nothing here. Q8_PACKED: qkv 7.35 vs 7.45. Drop the table on Orin.
- Harness: every result.json says `"supervisor": "fail"`, the baselines too, while status is ok. Looks like a
  harness quirk, not a signal.

### iteration 3 (2026-11-01 ~02:37-), e011-
- **e011 kv-grow + `--needles`: 26.54 (26.47-26.57), needles 3/3, texts = e007 1.0/1.0/1.0.** The 32K needle prompts
  ran the elastic path for real: `K/V grown to 40960 cells (0.56 GiB); the expert cache gave 167 slots for it, 51
  hotter experts moved to colder ones' slots`. Windows right after the growth show CPU experts 1.3-1.7 per
  layer-window and 35-48 ms per-layer host (the evicted experts go to the CPU until the cache re-settles), so at long
  contexts kv-grow's decode gain shrinks toward the baseline; 4K numbers hold for short contexts only.
  kv-grow is now PASS (placement only, needles ok, bitwise reproducible across 3 runs).
- Budget math (from e002's stage table, bytes per verify window): experts ~2.8 GB, dense projections 2.0 GB (300
  matrices), HC weights ~1 GB (80 reads x 2 x 6.5 MB bf16: w_down 320x10240 + w_up 10240x320), head 0.52 GB, draft
  ~0.3 GB/step. ~6.5 GB/window at ~120 GB/s = ~54 ms/window floor -> ~45 tok/s at 2.45 tokens/window: the target
  equals the bandwidth floor. Not reachable with switches; only fewer bytes per token (more tokens per window) or
  kernels at full bandwidth everywhere.
- Per-kernel bandwidth estimate (GDN, ~30 layers): HC down 2.18 ms for ~197 MB = ~90 GB/s; HC up 3.32 ms = ~59 GB/s
  (the weakest); head 5.4 ms for 521 MB = ~97 GB/s.
- **e012 kv-grow + STRATA_GR_FAST=1 + STRATA_GR_DOWN_MAX4=1: 26.97 (27.77 / 21.50 / 26.97). Not kept** (gain
  within noise; the text difference turned out to be placement, see the e013 entry below).
  Texts vs e007: 0.68 / 0.54 / 0.13, while e007/e009/e011 agree 1.0 with each other. So either GR_FAST's up kernel
  (gr_up_fast_kernel, fused_gr.cu:1028; its source claims the same xor tree as gr_up_multi_kernel and I could not
  spot a difference by reading) is not bitwise on sm_87, or the slot count (19090 vs 19068; e009/e011 had 19063/19057
  and still matched) moved a CPU expert. Note the card's start-up check ("staged ... checked bit for bit against the
  plain read") runs both sides with the SAME GR_FAST setting, so it does not validate fast vs non-fast. DOWN_MAX4 is
  inert on the staged path (launch_multi takes the exact-T instantiations for T <= 6 first). Speed: verify per
  window 81.3 ms @ T 3.17 and 80.5 @ T 3.15 vs e011 83.9 @ T 3.19 and 80.6 @ T 2.98: ~1-2 ms/window (1-2%), within
  noise; median +0.4 over e007, far below the 1.68 bar. Do not retry
  without a pinned-placement A/B (`--spec-follow --window-hashes` probe) to settle the bitwise question.
- **Stall mechanism (e012's 21.5 request):** `per-layer host 25.63 [CPU 25.36]` ms/window with only 0.05 CPU experts
  per layer-window: the few CPU experts take ~0.5 s each window-batch, i.e. the CPU expert path page-faults the
  mmap'd expert file from the SSD (or another tenant holds the CPU). Lever: `--resident-cpu-experts` (or pread/
  mlock of the ~5.5K uncached pairs' hot subset) so a miss never touches the SSD; judge on decode_min.
  `--resident-budget-gib N` (generate.cpp:2228) pins the N GiB hottest non-cached experts in RAM (same answers as
  mmap per its help); with min avail ~8.7 GiB and the 6 GiB floor, N <= ~1.5 is safe.
- **e013 kv-grow + STRATA_HC_SPLIT=1 (split instead of staged): 25.27 (25.27 / 26.02 / 6.38). No gain, not kept.**
  Clean windows: verify 84.5 @ T 3.21 and 86.9 @ T 3.38 vs e011 83.9 @ T 3.19 and 86.8 @ T 3.40: identical, so
  split vs staged makes no difference on Orin; drop the HC_SPLIT arms (0 not tried; it is the slowest by design).
  The 6.38 request is a PLE stall: `stage 285.45` ms/window (the PLE row gather) for the whole request.
- **The gate confound found: e012 and e013 (different HC kernels) diverge from e007 at the SAME points**
  (0.6752 / 0.5431 / 0.1308 each); e013 vs e012 = 0.71 / 1.0 / 1.0. Their shared difference from e007 is slots
  19090 / 19080 vs 19068. So the auto cache size still moves text whenever it lands above e007's (19057-19068 happened
  to match). The auto N -> slots map is deterministic (14621->19057, 14624->19062, 14625->19063, 14629->19068,
  14638->19080, 14646->19090), so **pin `--expert-cache 14629` with kv-grow to reproduce e007's placement**: then
  e007 is a valid bitwise reference for exact arms. e012's GR_FAST verdict is therefore open, not "not bitwise".
- **e014 kv-grow + `--spec-min-p 0.3`: 25.41 (26.26 / 25.41 / 24.64), slower; not kept.** avg T 3.72 (vs ~3.2),
  2.49-2.67 tokens/window, 101 ms/window (verify 90, draft 11). Verify costs ~15 ms per extra window token
  (fit over e011/e013: 80.6 @ T 2.98 -> 86.8 @ T 3.40), a token costs ~37 ms on average, so a marginal draft pays
  only if accepted > ~25%; the 0.3-0.5 drafts are below that. min-p 0.5 stays; 0.7 would cut drafts accepted
  more often than that. MTP min-p is done.
- **e014 texts = e012 texts 1.0 / 1.0 / 1.0** (slots 19092 vs 19090; e014 has no GR_FAST, other min-p). So (a) the
  drafting window does not change the output (the multi-column kernels are column-exact, as their comments say), and
  (b) GR_FAST is very likely bitwise: e012 differed from e007 by placement only. Text = f(placement) on this build.
- GR_FAST speed from the verify-vs-T fit (no GR_FAST: ~83.6 ms @ T 3.17): e012 81.3 @ 3.17 and 80.5 @ 3.15 ->
  ~2.5 ms/window saved, ~2.7% (~+0.7 tok/s). Real but below the 1.68 bar alone.
- **e015 kv-grow + `--expert-cache 14629` + STRATA_GR_FAST=1: 27.35 (27.27 / 27.35 / 27.40), slots 19068,
  texts = e007 1.0 / 1.0 / 1.0. PASS (bitwise; the pin reproduces e007's placement exactly).** Paired with e007
  (same windows 103 / 100 / 107, same T): 90.88 vs 93.52, 93.86 vs 96.64, 87.31 vs 89.88 ms/window = -2.6 to -2.8
  ms (-2.8%), all in GPU verify (draft and host unchanged). +0.77 over e007, **+2.47 over the baseline median
  24.88 (> 1.68)**. The pinned cache also takes the auto-size drift out of the gate: from here, arms on this base are
  judged by `python3 compare.py runs/<exp>/result.json runs/e015-pin14629-grfast/result.json` = 1.0.
  Caveat: 14629 is what auto picks at ~39.5 GiB free; if the Jetson has less free RAM at start, a pinned 14629 could
  push min avail toward the floor (here 8.76 GiB min avail, fine).
- **e016 = e015 again + `--needles`: 27.36 (27.36 / 8.70 / 27.36), needles 3/3, texts = e015 1.0/1.0/1.0.**
  Repeat confirms e015. Clean windows reproduce e015 within 0.2% (90.85 vs 90.88, 87.46 vs 87.31 ms/window). The
  needle run grew the K/V again (`K/V grown to 40960 cells ... 165 slots`). The 8.70 request is a PLE stall:
  `stage 200.40` ms/window for the whole request. Stalls tonight: PLE gather in e013 and e016 (and e003 earlier),
  CPU-expert in e012 -> **the PLE row path is now the top stall lever** (`--ple-row-cache`, `--ple-inflight`,
  SSD keep-alive), judged on decode_min over >= 3 runs on the e015 base.
- Iteration 3 used 6 experiments (e011-e016). No source changes; the tree is clean, nothing to commit.

### iteration 4 (2026-11-01 ~03:00-), e017-
- **e017 e015 + STRATA_VERIFY_DEVICE_PLAN=1 + STRATA_TSUM=1: 27.24 (27.14-27.31), texts = e015 1.0/1.0/1.0
  (bitwise), paired ms/window 91.25 / 94.33 / 87.61 vs e015 90.88 / 93.86 / 87.31 = +0.3-0.5 ms (slower).**
  DEVICE_PLAN adds `jobs 0.57-0.67` ms of host time per window and saves nothing (the GPU is the bottleneck:
  GPU-reach wait 70-75 of 78-84 ms verify). Drop both; do not retry.
- e006 vs e005 stage tables: STRATA_Q6_PACKED makes the head slower (5.59-5.67 vs 5.06-5.33 ms/window). The head
  is Q6_K (248320 x 2560, 521 MB: e006's "packed the output head" line; the "Q5_K head" log text is stale), the
  draft head is its 106299-row Q6_K subset (212.9 MiB). No Q8_0 dense matrices (Q8_PACKED packed none).
- **e018 (diagnostic) e015 + STRATA_VERIFY_PROFILE=1 + a new log line of the dense types (print only,
  native_dense.cpp; kept): 26.76, texts = e015 bitwise (gate line identical).** Profiling costs ~1.5-1.8 ms/window
  (92.71 / 95.67 vs e015 90.88 / 93.86). **Dense types** (t<ggml type>x<n_out>:count/MiB): Q6_K (14) 1292 MiB =
  64% (x2560 40/492 = the out-projections, x10240 22/451, x6144 14/172, x12288 5/123, x640 26/33, x512 21/21),
  Q5_K (13) 327 MiB (x10240 10/171), Q4_K (12) 187, IQ4_XS (23) 159, IQ4_NL (20) x2560 47/41, Q8_0 1. No Q3_K.
  **Reference stage table on the current base (request 1, 104 windows, T 3.18), ms/window:** dense 22.75 (GDN
  qkv 7.63, z 4.28, out-proj 5.27; QSA q 3.17, out-proj 1.84, k/v 0.56), head 5.40, experts 24.5 (18.73 + 5.78),
  HC 16.1 (hc-read1+router 6.45 + 2.15, hc0 norm/down/up 0.97/2.27/2.58 + 0.10/0.75/0.87; GR_FAST took hc0 up from
  3.32 to 2.58), shared+quant 4.14, attention+scores 4.47, total 82.41.
  **Bandwidth by stage**: out-proj 593 MB / 7.11 ms = 83 GB/s, qkv 709 MB / 7.63 = 93, z 378 MB / 4.28 = 88, QSA q
  259 MB / 3.17 = 82, head 521 MB / 5.40 = 97, experts ~120. Dense + head at the experts' 120 GB/s would save
  ~7.6 ms/window (~8%). The Q6_K x2560 out-projections take plain native kernels at every column count on sm_87
  (kIlRowsShared Q6_K class 1 = 0/0/0), the head (class 4) 0/2/1.
- **e019 e015 + new opt-in `STRATA_DRAFT_VOCAB_TOP=40960` (mtp.cpp: keep the first N tokens of
  <mtp>/draft_vocab.bin; draft head 82.0 vs 212.9 MiB): 28.32 (28.28 / 28.32 / 28.38), texts = e015
  1.0/1.0/1.0, PASS (drafting policy; every draft verified exactly). Commit 4a569815.** Drafts accepted
  154/225, 159/237, 149/212 vs e015 154/225, 159/237, 149/211: the first 40960 entries hold every token these essays
  use. Paired: draft 6.67 / 6.98 / 6.27 vs 9.97 / 10.44 / 9.34 ms/window, total 87.76 / 90.53 / 84.29 vs 90.88 /
  93.86 / 87.31 = -3.0 to -3.3 ms/window (-3.5%), verify unchanged. +0.97 over e015: below the 1.7 bar alone, so
  e015 stays the formal best until a stack clears it. The draft head was ~70% of a draft step: ~131 MiB less per
  step saved ~1 ms/step (~3.2 steps/window) = it reads at ~130 GB/s. Remaining draft ~6.6 ms/window = head ~2 ms +
  the MTP layer (dense Q8_0 111 MiB, its experts, HC read) ~4.5 ms. Caveat: the subset's order on disk is unknown
  (frequency or token id); for non-English or code-heavy prompts acceptance could fall: try a smaller N only with
  "drafts accepted" checked, and keep the default off upstream.
- **e020 (profiled) e018 + `STRATA_MMVQ_IL_ROWS="14:2:0,1,1,1,2;14:3:0,1,1,1,2;14:4:0,1,1,1,2"` (Q6_K: class 1 =
  the 2560-row out-projections 0 -> 1 row a warp at 2-4 columns; class 4 = head/QSA q 0/2/1 -> 2): 27.15
  (profiled; compare with e018's 26.76), texts = e015 1.0/1.0/1.0, PASS (bitwise by construction and by text).**
  Paired vs e018: 91.54 / 94.39 vs 92.71 / 95.67 ms/window (verify 81.56 / 83.94 vs 82.69 / 85.17 = -1.1 to
  -1.2 ms). Stage table: **out-proj GDN 4.58 vs 5.27, QSA 1.58 vs 1.84 (-0.95 ms, 83 -> 96 GB/s)**; head 5.28 /
  5.34 vs 5.40 / 5.37 (~neutral); everything else within 0.05. So the IL kernel at 1 row a warp beats the plain
  multi-column kernel on Orin where the shared table says 0. Not yet tried: Q6_K class 0 (x512/x640, 54 MiB),
  Q5_K/Q4_K class 1 (x2560, 74 MiB), rows 2/4 for classes 2/3 (qkv/z, now 1), and T = 5 windows (IL covers
  2-4 columns only; T 5 takes the plain kernels).
- **e021 stack e015 + DRAFT_VOCAB_TOP=40960 + the e020 IL rows, unprofiled, `--needles`: 28.76 (28.76 / 28.68 /
  28.76), needles 3/3, texts = e015 1.0/1.0/1.0, PASS.** Paired vs e015: 86.43 / 89.25 / 83.19 vs 90.88 / 93.86 /
  87.31 ms/window = **-4.1 to -4.6 ms (-4.9%)** = draft -3.2 + verify -1.2, the two parts add as measured
  alone. Drafts accepted 154/225, 159/237, 149/213. +1.41 over e015 (bar 1.7: not formally a new best yet),
  **+3.88 over the baseline median 24.88**. overrides/e021-pin-grfast-dvocab40k-q6il.json.
- **e022 = e021 with DRAFT_VOCAB_TOP=16384 (32.8 MiB): 26.86 (26.86 / 27.90 / 26.85), worse; not kept.** Texts
  still = e015 1.0/1.0/1.0 (drafting policy cannot change output: confirmed again). Drafts accepted 147/248,
  154/243, 143/241 vs e021 154/225, 159/237, 149/213, windows 110/105/113 vs 103/100/107: the first 16384 entries
  miss tokens these essays use, and the subset's softmax drops the missing tokens' mass, so the top-p >= 0.5 test
  passes more often and more drafts get offered and rejected. Draft 5.5-5.7 vs 6.3-7.1 ms/window did not pay for
  ~6% more windows. 40960 stays; between them (24576-32768) is at most ~0.5 ms/window: low priority.
- Iteration 4 used 6 experiments (e017-e022). Commit 4a569815 on ar/decode-speed (draft-vocab opt-in + type log);
  the IL rows are env only (no code). Tree clean.

### iteration 5 (2026-11-01 ~03:21-03:40), e023-e028
- **Stage map of the IL classes** (from e018's type line): class 0 = x512/x640 (shared-expert gate/up 96 matrices,
  QSA k/v), class 1 = x2560 (48 out-projections; Q6_K 40, Q5_K 4, Q4_K 4), class 2 = x6144 (36 GDN z), class 3 =
  x10240 (36 GDN qkv), class 4 = x12288 (12 QSA q) + the Q6_K head. The shared expert's IQ4_NL down (x2560) is not
  an IL type.
- **e023 (profiled) rows 1 at classes 0-3 for all four IL types: 27.16, texts = e015 1.0/1.0/1.0.** Stage totals
  81.21 / 84.20 / 78.66 vs e020 81.29 / 84.25 / 78.73 ms/window (-0.07): QSA k/v 0.45 vs 0.57, z -0.05, rest flat.
- **e024 (profiled) rows 2 everywhere: 27.09, texts 1.0/1.0/1.0.** vs e023: qkv 7.48 vs 7.59, z 4.13 vs 4.22, QSA q
  3.04 vs 3.14 (better); out-proj 4.83 vs 4.59 and QSA out-proj 1.69 vs 1.58, k/v 0.49 vs 0.45 (worse). Best per
  class: 0 -> 1, 1 -> 1, 2/3/4 -> 2, worth ~-0.47 ms/window profiled. shared+quant did not move in either arm.
- **e025 = e021 + that IL string + `--resident-budget-gib 1.5`: pressure_abort, min avail 5.84 GiB** (expected
  ~7.2; the resident mode takes more than its budget: page-locked copy + its 4 GiB headroom logic). **Do not use
  --resident-budget-gib on this Jetson** (at most a 0.5 GiB try, and only if a stall study needs it).
- **e026 = e021 + IL best per class (`1,1,2,2,2` for types 12/13/14/23 at ncols 2-4): 28.76 (28.81 / 28.66 /
  28.76), texts = e015 1.0/1.0/1.0.** Paired vs e021 (same windows 103/100/107): GPU-reach wait -0.16 to -0.25
  ms/window, totals 86.27 / 89.32 / 83.18 vs 86.43 / 89.25 / 83.19 = no net change. Profiled -0.47 shrinks to ~-0.2
  unprofiled (the shared expert runs on its own stream when not profiled, VERIFY_PROFILE serializes it).
  **IL-row tuning is done**: not kept (no needles run); the e021 string stays in the base.
- **e027 = e026 + `--expert-cache 15000` (19567 slots, 37.19 GiB, min avail 7.82): 28.23 (26.93 / 28.23 / 30.54),
  texts changed (placement) -> not paired.** The spread is acceptance: 2.21 / 2.46 / 2.59 tokens/window vs e026
  2.49 / 2.56 / 2.39. Against e026's verify-vs-T line, e027's windows cost the same within 0.5 ms (75.75 @ T 2.91,
  80.31 @ 3.28, 78.12 @ 3.10); per-layer host 1.27 / 1.72 / 1.84 vs 1.17 / 2.74 / 1.63, CPU experts 0.02-0.04 vs
  0.02-0.06 per layer-window. **No decode gain; prefill 297.6 vs 283 tok/s (TTFT 13.83 vs 14.53 s).** Not kept.
  Lesson: **any placement change re-rolls the texts and moves the median by +-2 tok/s through acceptance alone**;
  judge placement arms by ms/window at matched T, not by decode_med.
- **e028 = e026 + `--spec 3`: 28.39 (28.71 / 28.39 / 27.94), texts = e015 1.0/1.0/1.0, worse; not kept.** Paired
  per request: 8916 / 9019 / 9164 ms vs e026 8886 / 8932 / 8900 for 256 tokens (+0.3 / +1.0 / +3.0%). Drafts
  accepted 142/189, 143/193, 135/179 vs 154/225, 159/237, 149/213; windows 114/114/121 vs 103/100/107.
  **Verify cost model from e026 + e028 (same texts, two T levels): verify ~= 40 ms + 12.5 ms per window column**
  (slopes 12.9 / 12.5 / 12.1 ms per T), draft ~2 ms per step. Per token at T 3.2 and 2.49 tokens/window:
  (40 + 40 + 6.7) / 2.49 = ~34.8 ms -> 28.8 tok/s. 45 tok/s (22.2 ms/token) needs both the fixed 40 ms (dense 22 +
  HC 15 + head 5, read once a window) and the 12.5 ms per column (the column's new experts, ~7-10 per layer) cut by
  ~35%: kernels, not switches.
- Iteration 5 used 6 experiments (e023-e028). No source changes, nothing to commit; tree clean.

### iteration 6 (2026-11-01 ~03:38-), e029-
- **e029 = e021 + `--spec 5`: 25.03 (25.03 / 6.37 / 25.67), texts = e015 1.0/1.0/1.0, much slower; not kept.**
  Windows 97/92/99 vs e026 103/100/107 (drafts accepted 161/263, 164/266, 157/246), but verify 97.46 @ T 3.71 and
  93.25 @ T 3.48 ms/window vs e026's line (79.53 @ 3.18, slope ~12.5/T) predicting ~86.2 and ~83.3: **+10-11 ms a
  window beyond the per-column cost**. Per request 10.2 s vs e026 8.9 s (+15%). So 5-6 column windows are far
  dearer than 2-4 column ones: the dense GEMVs there take the plain multi-column kernels (IL covers 2-4 only), and
  the engine also captured a 7-token window graph. The 6.37 request is a CPU-expert stall: per-layer host 331 ms
  [CPU 330.8] a window with 0.07 CPU experts per layer-window (the CPU path faulting the mmap'd expert file).
- Expert path checked (verify.cpp post/grouped): experts are grouped per window (plan p_start/p_counts per expert,
  tokens listed), so an expert shared by two window columns is read once. "VRAM hits" per layer-window counts
  entries (~10 x T). No dedupe lever there.
- **`--spec N` means windows of at most N tokens** (N - 1 drafts): at spec 4 the engine captures 1/2/3/4-token
  windows (+ one 6-token graph that never runs in these requests), at spec 5 it adds 5 and 7. So 5-6 column GEMVs
  never run at the base's spec 4.
- **e030 (code, reverted) IL kernels for 5-6 columns** (launch_il cases 5/6, interleave and supported() up to 6,
  ncols 5-6 take the 4-column rows, xil_ sized for cp 8): 28.74 (28.70-28.75), texts = e015 1.0/1.0/1.0,
  ms/window 86.49 / 89.21 / 83.22 vs e026 86.27 / 89.32 / 83.18 = neutral, as it must be at spec 4. Not kept: only
  useful with spec 5, and spec 5 loses even with linear-cost 5-column windows: (40 + 12.5 x 3.71 + 7.9) / 2.64 =
  35.7 ms/token vs spec 4's (40 + 39.75 + 6.7) / 2.49 = 34.7; the 4th draft is accepted 7 of 38 times (18%) in
  e029, below the ~40% a marginal draft needs (12.5 ms verify + ~2.4 ms draft step vs ~35 ms a token). **MTP spec
  is settled at 4** (3: e028 worse, 5: e029 worse).
- **Shared-memory traffic in the HC kernels** (arithmetic): every row of a bf16 HC GEMV re-reads all T activation
  vectors from shared memory. Down (staged, 8 warps = 8 rows a block): 324 rows x T x 40 KB = ~53 MB of smem reads
  per call at T 4 vs 6.5 MB of DRAM weights; at 16 SMs x 128 B/clk that alone is ~20 us of the ~63 us call. Up
  (gr_up_fast_kernel): each 8-lane group computes 2 rows and read the token's 5 activation chunks once a row.
- **e031 (code) gr_up_fast_kernel reads each token's activation chunks once for both rows: 29.20 (29.17 / 29.20 /
  29.23), texts = e015 1.0/1.0/1.0 (bitwise; per row the same dot8 FMAs on the same operands and the same
  `(p0+p2)+(p1+p3)` xor tree).** Paired vs e030 (same windows 103/100/107, drafts 154/225, 159/237, 149/213):
  85.04 / 87.76 / 81.94 vs 86.49 / 89.21 / 83.22 ms/window = **-1.28 to -1.45 ms (-1.6%)**, all in verify
  (78.35 vs 79.76). **+1.85 over e015's 27.35 (> 1.7)**: the first stack past the bar; needs a repeat.
- **e032 (code, removed) e031 + STRATA_GR_DOWN2=1: the staged down kernel with 2 rows a warp, 4 warps a block (same
  41 blocks), each staged activation read once a warp for both rows: 29.22 (29.16-29.22), texts 1.0/1.0/1.0, the
  startup self-test passed it bit for bit against the plain read. Neutral:** 85.05 / 87.80 / 81.87 vs e031 85.04 /
  87.76 / 81.94 ms/window. So the down kernel is not bound by smem reads (or the 4-warp blocks lose the gain in
  latency hiding); the up kernel was. Code removed (source in runs/e032-grdown2/source.diff).
- **e033 = e031 again + `--needles`: 29.14 (29.11 / 29.14 / 29.14), needles 3/3, texts = e015 1.0/1.0/1.0.**
  Paired windows 85.30 / 87.93 / 82.11 vs e031 85.04 / 87.76 / 81.94 (within 0.3 ms). **Repeat confirms: e031 is
  the new best (PASS), committed as 9b87a9c0 on ar/decode-speed.** min avail 8.7 GiB.
- overrides/e031-dvocab32k.json was written early and never run under that id (e031 became the kernel arm); the
  draft-vocab 32768 arm ran as e034 (overrides/e034-dvocab32k-grup.json).
- **e034 = e031 build + STRATA_DRAFT_VOCAB_TOP=32768: 27.53 (27.25 / 27.53 / 29.22), texts = e015 1.0/1.0/1.0,
  worse; not kept.** Drafts accepted 148/247, 158/233, 143/228 vs 154/225, 159/237, 149/213; windows 109/101/113 vs
  103/100/107; draft 6.40 / 6.48 / 5.98 vs ~6.7 / 7.0 / 6.3 ms/window (-0.3) did not pay for 2-6% more windows
  (86.19 / 86.75 / 82.29 ms/window). As with 16384 (e022), the subset's missing tokens pass more drafts that then
  fail. **Draft-vocab tuning is done: 40960 stays** (anything between 32768 and 40960 is worth < 0.3 ms/window).
- Iteration 6 used 6 experiments (e029-e034). Kept: e031's kernel change, commit 9b87a9c0 on ar/decode-speed
  (e033 = repeat + needles 3/3). All other source changes removed; tree clean.

### iteration 7 (2026-11-01 ~04:00-04:30), e035-p037
- **e035 (profiled) IL rows 4 at classes 2-4 (qkv/z/q/head), 1 at classes 0-1, all four IL types: 27.01, texts =
  e015 1.0/1.0/1.0, slower.** vs e024 (rows 2): qkv 8.31 vs 7.48, z 4.78 vs 4.13, head 5.66 vs 5.26, QSA q 3.44 vs
  3.04 ms/window. Rows 4 costs registers/occupancy. **IL rows are done for good: 1,1,2,2,2 is the optimum.** The
  same table shows e031's kernel in the profile: hc0 up 2.05 / 0.70 vs 2.56 / 0.86 (-0.67 ms a read), hc-read1+router
  5.95 / 1.99 vs 6.48 / 2.16. HC up is now ~57 us a call = ~115 GB/s: little left there, so the "4 rows per 8-lane
  group" idea (old next step 1) is worth <= ~0.5 ms. Dropped.
- **QSA "attention" 3.85 ms/window is mostly the q GEMV**: with the query branch (qbr) on its own stream, stamp 13
  comes after `join(0)` (verify.cpp:2054), so the stage holds the wait for the x12288 q projection. It is not
  an attention-kernel target.
- **e036 (code, reverted) IQ3_S added to kStageIqGrid** (the grouped gate/up native_gu_multi_kernel<21> reads the
  2 KB iq3s grid from shared memory, as IQ2/IQ1 already do): 29.29 (29.25-29.31), texts = e015 1.0/1.0/1.0
  (bitwise). Paired ms/window 84.81 / 87.53 / 81.68 vs e031 85.04 / 87.76 / 81.94 = -0.23 to -0.26 (-0.3%), inside
  the e031-vs-e033 repeat spread (0.17-0.26). **The L1 grid gathers do not limit the expert kernel.** Not kept;
  source in runs/e036-iq3s-stage-grid/source.diff.
- **p037 roofline (new opt-in STRATA_BW_PROBE=1, committed a3be9f75, inert without the env): the Orin GPU streams
  reads at ~180 GB/s** (512 MiB, uint4 loads: 4 or 8 in flight per thread 172-180 GB/s at 2-6 blocks of 256 per
  SM; ONE load in flight 101 / 135 / 167 GB/s at 2 / 4 / 6 blocks per SM), D2D copy 191 GB/s read+write.
  **So the decode kernels (experts ~100-120, HC ~103-115, head 97, dense 83-95 GB/s) are 1.5-2x below the DRAM,
  and they are latency/issue bound, not bandwidth bound.** Revised floor: ~6.5 GB/window at 180 GB/s = 36 ms + draft
  ~4.5 ms -> (36 + 4.5) / 2.49 = ~16 ms/token = ~60 tok/s. 45 tok/s needs ~55 ms/window (now 85): -30 ms, i.e.
  every big kernel near ~150 GB/s. Hard, but no longer "beyond physics".
- Why the kernels are slow (code reading, to test): Q6_K blocks are 210 B (2-byte aligned) and IQ3_S blocks 110 B,
  so the dense IL kernel and the expert gate/up read their weights as 16-bit pairs (load_int_b2 / get_int_b2): ~7
  small loads a lane per Q6_K block and ~9 per IQ3_S call, plus per-column activation loads. The probe says one
  narrow load chain per thread at low occupancy gets ~100 GB/s, which is where these kernels sit.
- **HC down (gr_down_staged, ~103 GB/s, ~3 ms a read, ~6 ms/window for both reads):** each lane already keeps 5+5
  uint4 of weights in flight, but each of the 41 blocks also stages all T tokens' 40 KB activations from L2
  (41 x T x 40 KB, about the weight bytes again) behind two __syncthreads per 1280-float tile. e032 (2 rows a warp,
  4 warps a block, still 41 blocks) did not cut that staging. The lever is fewer blocks sharing one staging pass
  (e.g. 16 rows a block, 2 per warp x 8 warps, 21 blocks: half the L2 staging, but 21 blocks on 16 SMs is uneven),
  keeping each row's lane order (bitwise).
- **e038 (code, reverted) gr_down_staged_kernel loads each lane's weights two tiles ahead instead of one** (same
  values, same order; the startup check passed it bit for bit): 29.07 (29.07 / 7.04 / 29.09), texts = e015
  1.0/1.0/1.0. Clean requests 85.50 / 82.24 ms/window vs e033 85.30 / 82.11 (GPU-reach wait +0.06-0.08): neutral to
  slightly worse. **HC down is not weight-latency bound at a one-tile lookahead**, and not smem-read bound (e032).
  What is left there: the per-tile barriers, the per-block L2 staging, and the 41-block imbalance (9 SMs run 3
  blocks, 7 run 2). The 7.04 request is a PLE stall (`stage 275.52` ms/window for the whole request), the first stall
  in ~24 requests since iteration 5. Same type as e013/e016.
- Harness: `git -C ... checkout -- src include cmake CMakeLists.txt` was denied by the permission layer this
  iteration; the e036 and e038 reverts were done by hand with Edit (tree verified clean with `git status`).
- Iteration 7 used 4 runs (e035, e036, p037, e038). Commit a3be9f75 (diagnostic only). Tree clean.

### iteration 8 (2026-11-01 ~04:28-05:00), e039-p042
- **e039 (code, reverted) row_dot_80_sub16 (IQ3_S expert gate/up, 16 lanes a row) wrote out its two strided loops
  (fixed 3 + 2 chunks since t < 16) and issued all 5 chunk loads before the first dot: 27.72 (27.66-27.74), texts =
  e015 1.0/1.0/1.0 (bitwise), but ms/window 89.66 / 92.56 / 86.26 vs e031 85.04 / 87.76 / 81.94 = +4.3 to +4.8
  (+5.5%).** Five decoded weight sets (Split<21>::W = 10 registers each) live at once cost resident warps. The gate/up
  kernel is NOT bound by per-lane load latency (same lesson as e038 for HC down). Source: runs/e039-gu-hoist/source.diff.
- **e040 (code, reverted) gate/up SUB16 path stages the n tokens' q8_1 rows (n x 2880 B) in shared memory per entry
  chunk, as native_down_multi_kernel stages hq (conflict-free: a lane's blocks sit 9 words apart): 29.01
  (28.96-29.02), texts 1.0/1.0/1.0, 85.65 / 88.39 / 82.47 ms/window = +0.5-0.6 vs e031.** L1 activation reads are not
  the gate/up limit either; the two barriers + staging cost more. Source: runs/e040-gu-stage-x/source.diff.
- **p041 (STRATA_BW_PROBE rows mode): a warp a row, 128-thread blocks (the IL GEMV pattern), rows of 1104 / 2112 /
  5040 B, 2-, 4- or 16-byte loads, 1 or 4 in flight: 159-180 GB/s in every case** (2-byte loads, 1 in flight: 159 /
  179 / 169). Many concurrent row streams and narrow loads are fine for the DRAM.
- **p042 (launch-size sweep, GEMV-pattern pure reads, 16-64 launches captured in one graph, fresh memory each):**
  512 KiB 96.0 GB/s (5.46 us a launch), 1 MiB 124.5 (8.41), 2 MiB 146.4 (14.3), 4 MiB 161.4 (26.0), 8 MiB 168.4
  (49.8), 16 MiB 174.1 (96.3), 32 MiB 177.3 (189.2). **Fit: ~2.5 us a launch + bytes at ~180 GB/s.** The dense
  matrices (2-12 MiB) could read at 146-172 GB/s and the expert launches (20-35 MB a layer) at ~175; they run at
  83-120. **So the decode kernels are bound in their bodies (instruction issue at the occupancy they get), not by
  DRAM, access pattern, or launch count.** That fits every kernel result so far: e031 (fewer smem-read instructions)
  helped; more loads in flight (e038, e039) and staging (e040) did not.
- Issue estimate, Q6_K IL at 4 columns: per 210-byte block a lane runs ~7 weight loads + 4 activation loads + ~10
  decode ops + ~10 ops a column (IDP4A, IMUL, I2F, FFMA x2, FMUL, FADD) + address math ~10 = ~80 warp instructions:
  ~2 GB of dense a window = ~9.5 M warp-blocks x 80 = ~7.6e8 warp instructions = ~9 ms at 1.3 GHz on 64 schedulers
  with perfect issue, against ~21 ms measured. The decode (vil/vih/vsubss4 in q6_q8_dot_impl) is the same SSA
  expression for every column, so the compiler should already share it; the per-column ops are what the math needs.
  The GPU clock (1.3 GHz assumed) is unverified: the operator could check `nvpmodel -q` on the Jetson.
- Harness: `git checkout -- ...` and `git branch --show-current` are still denied; reverts done with Edit, the branch
  read from .git/HEAD (ar/decode-speed). Commit 59190a06 = the probe extension only (inert without the env).
- Iteration 8 used 4 runs (e039, e040, p041, p042). No decode gain; current best unchanged (e031/e033). Tree clean.

### iteration 9 (2026-11-01 ~04:48-05:27), e043-e048
Pairing reference for e031's build: 85.04 / 87.76 / 81.94 ms/window (windows 103/100/107); verify across
e031/e033/e036 78.10-78.57 / 80.50-80.89 / 75.39-75.81, draft 6.66-6.74 / 6.97-7.05 / 6.24-6.32.
- **e043 (code) q6_q8_dot_impl for every Q6_K path: vi = ((v | 0x80808080) - 0x20202020) ^ 0x80808080 instead of
  __vsubss4 (bytes 0..63: never saturates, same ints) and int->float as `__int_as_float(0x4B400000 + n) -
  12582912.0f` instead of I2F (|n| <= 2^21 < 2^22: exact; __fsub_rn so nothing is contracted): 29.23, texts 1.0.**
  Verify -0.34 to -0.52 ms/window, but **draft +0.30 to +0.33** (one-column Q6_K draft head got slower; cause not
  found, register/schedule change in the plain kernel is the guess). Net ~-0.1.
- **e044 = the same on the IL kernel only (`q6_q8_dot_impl<true>` in IlQ6K; plain/draft on the old expression):
  29.42 (29.38-29.43), texts 1.0, ms/window 84.48 / 87.13 / 81.29 = -0.56 / -0.63 / -0.65 vs e031, draft back to
  6.67 / 6.98 / 6.26.** I2F (16 a clock per SM on sm_8x) + the emulated __vsubss4 were worth ~5% of the Q6_K IL time.
- **SM clock measured (e044, new STRATA_BW_PROBE part): 1286-1294 MHz under a full-load spin, 1257-1263 MHz for
  short spins after 20 ms host idle; attribute max 1300.** The GPU runs at its MAXN clock: the clock is not why the
  kernels sit at ~50% of the issue estimate. Power mode is ruled out.
- **e045 (code) Split<21>::load (IQ3_S expert gate/up): the grid signs as `t = (n * 0x00204081) & 0x01010101; g =
  (x ^ (t * 0xFF)) + t`** (n = 4 sign bits; the multiply puts bit k at bit 8k; ~x + 1 stays in its byte because IQ3_S
  grid bytes are 2l+1, never 0) instead of __vcmpne4 + __vsub4 (~17 -> 6 ops a grid int): 29.50, texts 1.0.
  Requests 2/3: 86.78 / 80.93 = -0.35 / -0.36 vs e044 (request 1 had a PLE stall, `stage 17.32`). **Far below the
  instruction-count estimate (~25% of gate/up instructions removed): gate/up is not issue-bound either.**
- **e046 = e045 again + needles + a register/occupancy print: 29.47 (29.43-29.48), needles 3/3, texts 1.0.**
  84.35 / 86.98 / 81.16 (-0.13 to -0.15 vs e044, so the sign change is worth ~0.15-0.35). Committed df9a7871.
  **Registers (cudaFuncGetAttributes) and blocks a SM:** Q6_K IL nc2 r1 56 / 9x128, nc3 r1 64 / 8, nc4 r1 70 / 7,
  nc2 r2 64 / 8, **nc3 r2 80 / 6, nc4 r2 96 / 5 (= 20 warps a SM of 48)**, IQ4_XS nc3 r2 96 / 5; **gate/up
  native_gu_multi_kernel<21> 64 regs, 48 B local, 4x256 (32 warps)**; down native_down_multi_kernel<20> 64 regs,
  2880 B smem, 48 B local, 4x256. The 48 B local is the `s4[t]` / `s3[t]` dynamic-index stores at the row ends.
- **e047 (code) native_gu_multi_kernel `__launch_bounds__(256, 5)`: 48 registers (local still 48 B, no new spill),
  5 blocks = 40 warps a SM: 29.76 (29.80 / 29.76 / 29.17), texts 1.0.** 83.41 / 86.03 / 82.03; the third request
  had `per-layer host 3.11 [CPU 2.90]` (CPU-expert side noise), its GPU-reach wait 67.29 vs 68.20. GPU side -0.91
  to -0.97 ms/window vs e046.
- **e048 = e047 again + needles: 29.77 (29.75-29.80), needles 3/3, texts 1.0; 83.48 / 86.06 / 80.29 ms/window
  (-0.87 / -0.92 / -0.87 vs e046; -1.56 / -1.70 / -1.65 vs e031).** Committed 241e3e25.
- **Lesson: occupancy is the lever that pays.** ALU cuts gave 0.15-0.6 ms each; 8 more warps a SM on the gate/up
  kernel gave ~0.9 ms. Together with e039 (more live registers = slower) the decode kernels look latency-bound at
  their occupancy: more resident warps hide it, more ILP per warp does not.
- Iteration 9 used 6 runs (e043-e048). Commits df9a7871, 241e3e25 on ar/decode-speed. Tree clean.

### iteration 10 (2026-11-01 ~05:25-05:55), e049-e054
Pairing reference: e048 83.48 / 86.06 / 80.29 ms/window (windows 103/100/107). All arms on e044's overrides.
- **e049 (code, reverted) native_down_multi_kernel `__launch_bounds__(256, 5)`: 48 registers but local 48 -> 112 B
  (spill), 29.58; 84.03 / 86.70 / 80.84 = +0.55 to +0.64 ms/window. Slower.** The IQ4_NL down kernel does not fit
  48 registers.
- **e050 (code, kept) `lane_pick(s, t)`: a select chain instead of `s[t]` at the grouped expert kernels' row-end
  stores (gate/up SUB16, down sub8/sub16): 29.90, texts 1.0; 83.13 / 85.71 / 79.98 = -0.31 to -0.35.** Down's local
  48 -> 0 B (64 registers, 4 blocks). Gate/up still prints 48 B local: that is its never-run row_dot_multi fallback
  (`s4[lane]`, xb != 80), not the SUB16 path.
- **e051 (code) native_mmvq_il_kernel `__launch_bounds__(128, R == 1 ? 8 : 6)`: 30.50 (30.44-30.53), texts 1.0;
  81.42 / 84.09 / 78.45 = -1.53 to -1.71 vs e050.** Registers: Q6_K r1 nc2 48 / 10 blocks, nc3 61 / 8, nc4 61 / 8
  (was 56/9, 64/8, 70/7); r2 nc2 68/7, nc3 80/6, nc4 80/6 + 24 B local, IQ4_XS nc3 r2 80/6 + 32 B local.
- **e052 (code, reverted) rows 1 at `(128, 9)`: nc3/nc4 r1 56 registers / 9 blocks, no local, 30.03; 82.78 / 85.73 /
  79.68 = +1.2 to +1.6 vs e051. 56 is past the optimum** (no spill, but slower): 61-64 registers / 8 blocks is the
  sweet spot for the rows-1 IL kernels (70/7 and 56/9 both lose ~1.5 ms).
- **e053 (code, kept) rows 1 at 8, rows 2 at min-blocks 1: 30.47 (30.42-30.52), texts 1.0; 81.43 / 84.16 / 78.53 =
  e051 within 0.08.** The rows-2 cap is neutral; e051's whole gain is the rows-1 cap (Q6_K qkv/z/out-proj at 3-4
  columns). Note: `__launch_bounds__(128, 1)` is NOT the same code as `__launch_bounds__(128)`: rows 2 now get
  78 / 95 / 94 registers (nc2/3/4) and IQ4_XS nc3 r2 128 (was 64 / 80 / 96 / 96), with no speed change.
- **e054 = e053 again + needles: 30.38 (30.45 / 27.57 / 30.38), needles 3/3, texts 1.0.** Requests 1/3 81.62 / 78.76
  (e053 within 0.2); request 2 had a stall: `per-layer host 10.86 ... stage 8.52` ms/window (PLE type). Committed
  cda89788 (e053's build).
- **Lesson (confirms iteration 9): occupancy caps pay when they add warps without spilling; one notch too far (e052)
  or a spill (e049) loses as much as the notch gains.** Read registers + local from the BW probe on every cap arm.
- Iteration 10 used 6 runs (e049-e054). Commit cda89788 on ar/decode-speed. Tree clean.

### iteration 11 (2026-11-01 ~05:55-06:30), e055-e060
Pairing reference: e053 81.43 / 84.16 / 78.53 ms/window, GPU-reach wait 67.96 / 69.50 / 65.68 (windows 103/100/107).
- **Occupancy print extended (kept, inert without STRATA_BW_PROBE=1):** gr_norm_split 40 regs / 6 blocks of 256;
  **gr_down_staged T1 72 / T2 80 (8 B local) / T3 84 -> 2 blocks a SM (9 of its 41 blocks a second wave) / T4 80
  (8 B local), 3 blocks; gr_up_fast_kernel 127 registers, 2 blocks a SM** (cause: `unpack8` of its 10 weight uint4
  is loop-invariant over the tokens, so the compiler keeps 80 unpacked floats live); IL IQ4_XS nc3 r1 64 / 8;
  plain 1-column Q6_K (draft head) 40 regs / 12 blocks of 128, plain 1-column Q8_0 (MTP dense) 39 / 12.
- **e055 (env) IL rows 1 at classes 1-4 for all four IL types (Q6_K class 4 2 -> 1, Q4_K/Q5_K/IQ4_XS table cells
  0/2/4 -> 1): 30.29, texts 1.0; GPU-reach wait 69.56 / 65.69 vs 69.50 / 65.68 = neutral.** Request 1 a PLE stall
  (`stage 291` ms/window). IL rows are settled for good (head/QSA q at rows 1 or 2: same).
- **e056 (code, reverted) gr_down_staged and gr_up_fast at `__launch_bounds__(256, 3)`: 30.08, texts 1.0; 82.50 /
  85.21 / 79.54 = +1.0 ms/window each.** Up spilled (80 regs, 96 B local), staged down T4 8 -> 16 B local.
- **e057 (code, reverted) only the T3 staged-down launch capped (same body as a separate `(256, 3)` kernel: 80 regs,
  8 B local, all 41 blocks resident): 30.41, texts 1.0; GPU-reach wait +0.22 to +0.27.** Giving T3 its third block a
  SM did not help: HC down is not occupancy-limited. HC down is done (e032, e038, e057).
- **Unaccounted ~5.6 ms in "verify" is not host overhead**: ms_wait only sums the per-layer flag waits; the GPU work
  after the last layer (head ~5.4 ms + sampling) lands in verify outside it.
- **e058 (code, kept) opt-in STRATA_VRAM_GY=N** (verify.cpp post(): the VRAM-hit `native_expert_grouped` call
  passes grid_groups N instead of 0; 0 = cap = T x 10 block rows, of which cap - n_groups (~20-40%) read n_groups
  and exit; the gate/up and down kernels already stride `g += gridDim.y`, native_grouped_parity checks strides
  1-4 bitwise; on sm_87 exp_mode() is 0 either way, so the kernels are the same). **N=16: 30.73, texts 1.0;
  GPU-reach wait 67.20 / 68.62 / 65.01 = -0.67 to -0.88.**
- **e059 N=8: 30.94 (30.93-31.01), texts 1.0; 80.15 / 82.75 / 77.35 ms/window = -1.18 to -1.41 vs e053.** Fewer
  blocks, each ~3 groups: the gain is per-block overhead (launch, n_groups read, 2 barriers, staging) shared over
  more work, not only the dead rows (N=16 removes nearly all dead rows and gets ~60% of N=8's gain).
- **e060 = e059 again + needles: 30.98 (31.05 / 30.98 / 13.76), needles 3/3, texts 1.0.** Requests 1/2 80.04 / 82.63
  (e059 within 0.12); request 3 a CPU-expert stall (`per-layer host 98.08 [CPU 97.87]`, GPU-reach wait 64.38 = e059's
  64.57). **New formal best: +1.74 / +1.78 over e031.** Committed c6f7ca32.
- Iteration 11 used 6 runs (e055-e060). Commit c6f7ca32 on ar/decode-speed. Tree clean.

### iteration 12 (2026-11-01 ~06:20-), e061-
Pairing reference: e059 80.15 / 82.75 / 77.35 ms/window, GPU-reach wait 66.77 / 68.20 / 64.57 (windows 103/100/107).
- **e061 (env) STRATA_VRAM_GY=4: 30.89 (30.89-30.93), texts = e015 1.0/1.0/1.0; 80.35 / 82.88 / 77.45 ms/window
  = +0.10 to +0.20 vs e059. Neutral/slightly worse: GY=8 is the optimum** (16 -0.7..-0.9, 8 -1.2..-1.4, 4 -1.1..-1.2
  vs cap). GY tuning done.
- **e062 (code, reverted) opt-in STRATA_DOWN_NOSTAGE=1: native_down_multi_kernel (IQ4_NL sub8) reads hq from global
  memory at the same offsets instead of the shared copy behind two __syncthreads per entry chunk: 30.94, texts =
  e015 1.0/1.0/1.0; 80.10 / 82.73 / 77.35 = -0.05 / -0.02 / 0.00 vs e059. Neutral** (registers 64, 4 blocks either
  way; the variant had 16 B local). The down kernel's staging + barriers cost nothing measurable. Source:
  runs/e062-down-nostage/source.diff. Do not retry.
- **e063 (code) opt-in STRATA_GR_UP_LR=1: HC up as gr_up_fast_lr_kernel = the same body (now
  gr_up_fast_body<LOWREG>) under `__launch_bounds__(256, 3)`, the 10 weight uint4 kept packed across the token loop
  (an empty `asm volatile("" : "+r"(...))` per token stops the compiler hoisting 80 unpacked floats) and each chunk's
  activations loaded next to their use (same dot8u FMAs, same p0 = d0 + d4, same `(p0+p2)+(p1+p3)` xor tree):
  **80 registers, 0 B local, 3 blocks a SM (was 127 / 2). 31.02 (31.02-31.12), texts = e015 1.0/1.0/1.0;
  79.87 / 82.52 / 77.13 ms/window = -0.28 / -0.23 / -0.22 vs e059** (GPU-reach wait -0.31 to -0.40; ~2x the
  e059-e060 repeat spread of 0.11-0.12). Small, real; kept in the tree for stacking.
- **e064 (code, removed) opt-in STRATA_MMVQ1_ROWS4=1 on e063: one-column Q6_K / Q8_0 GEMVs (draft head, MTP dense)
  in the existing SmallK layout (4 rows a block; per row the same order, bitwise): 30.63, texts 1.0; draft 7.30 /
  7.64 / 6.85 vs 6.69 / 7.00 / 6.27 ms/window = +0.6 slower.** Registers Q6_K 40 -> 72 (12 -> 7 blocks), Q8_0 39 -> 55
  (12 -> 9). Same lesson as e039/e052: fewer resident warps lose more than 4 rows of ILP gain.
- **e065 (code) opt-in STRATA_MMVQ1_WARP=1 on e063: one-column Q6_K / Q8_0 GEMVs as one warp a row**
  (native_q6_k_mmvq_warp_kernel, native_small_mmvq_warp_kernel): lane l keeps the 4 sums warps 0..3 kept (thread
  32 v + l's blocks, same order), adds them ((t0 + t1) + t2) + t3 as the smem partials were added, then the same
  warp_sum; no smem, no barrier, no 3-vs-2 block imbalance between the warps. **31.31 (31.18-31.31), texts = e015
  1.0/1.0/1.0; draft 6.19 / 6.47 / 5.81 vs e063 6.69 / 7.00 / 6.27 (-0.46 to -0.53 ms/window); totals 79.37 /
  82.11 / 76.42 = -0.64 / -0.64 / -0.93 vs e059.** Registers: Q6_K warp 38 / 12 blocks (full), **Q8_0 warp 63 / 8
  blocks** (was 39 / 12): the 4-way unrolled Q8_0 loads cost occupancy; a cap could give more (next steps).
- **e066 = e065 again + needles: 31.38 (31.39 / 26.86 / 31.38), needles 3/3, texts = e015 1.0/1.0/1.0.** Requests
  1/3: 79.19 / 76.25 ms/window (e065 within 0.2). Request 2 a CPU-expert stall (`per-layer host 15.38 [CPU 15.12]`
  ms/window; 101 windows at T 3.33 instead of 100 at 3.37, same text). min avail 8.7 GiB. **Committed 2e7a8bdf**
  (e063 + e065 code; e061/e062/e064 left nothing in the tree). +0.37 / +0.40 over e059/e060: below the 1.7 bar, so
  e059/e060 stays the formal best; e065/e066 is the leading candidate.
- Iteration 12 used 6 runs (e061-e066). Commit 2e7a8bdf on ar/decode-speed. Tree clean.
- Harness: `git checkout -- <file>` and `git diff -- <file>` are still denied (`git diff --stat` and `status` work);
  reverts by hand with Edit; check with `git status --short`.

### iteration 13 (2026-11-01 ~06:47-07:20), e067-e071
Pairing reference: e065 79.37 / 82.11 / 76.42 ms/window, verify 73.15 / 75.60 / 70.58, draft 6.19 / 6.47 / 5.81
(windows 103/100/107).
- **e067 (code, kept) opt-in STRATA_NO_PCIE=1 + Q8_0 warp-kernel cap: 31.69 (31.54-31.70), texts = e015
  1.0/1.0/1.0; 78.41 / 81.17 / 75.49 ms/window.** NO_PCIE: expert_source.cpp:3356 plans no PCIe share for decode
  windows (the kMaxWindowEntries <= 128 path, so prefill is untouched) and verify.cpp post() skips fetch_blobs +
  rebase_ptrs + the PCIe `grouped()` (gu / swiglu / down over kPcieGroupRows block rows, all with 0 groups): ~5
  launches a layer, 200 a window. Verify -0.87 to -0.90 ms/window (~4.5 us a skipped launch; e035's profile said
  0.44). Q8_0 `native_small_mmvq_warp_kernel` at `__launch_bounds__(128, 12)`: 63 -> 38 registers, 12 blocks a SM,
  no local; draft -0.05 ms/window (small, kept). **The PCIe share is 0.00 in every window of e066 and e070, even the
  32K needle windows with 1.3-1.8 CPU experts per layer-window**, so NO_PCIE moves no expert on this Jetson
  (pcie_layer() or the >= 2-miss rule never fires): pure launch removal.
- **e068 (code, reverted) on e067: skip the flagB wait + fuse the flagA wait into the plan copy (1 block) + fuse the
  CPU-share wait into copy_rows_from_mapped (n x K blocks, thread 0 of each spins): 31.52, texts 1.0; 78.84 /
  81.65 / 75.90 = +0.2 to +0.3 vs e070.** Fusing 1-thread waits into copies does not pay (40 blocks polling the mapped
  flag, or the wait kernel overlapping the previous kernel's tail). Source: runs/e068-nopcie-fuse/source.diff.
- **e069 (code, reverted) on e067: flagB wait skipped only: 31.56, texts 1.0; 78.75 / 81.47 / 75.76 = e070 within
  0.09. Neutral.** A 1-thread spin kernel whose flag is already set costs nothing measurable; the e067 gain came from
  the many-block empty launches (gu/down grids, fetch_blobs), not from launch count as such.
- **e070 = e067 again + needles: 31.60 (31.46-31.62), needles 3/3, texts 1.0; 78.66 / 81.38 / 75.67 ms/window.**
  e067 ran ~0.2 ms fast; the mean of the two is -0.84 ms/window vs e065. Committed **108bd50f** (e067's code).
- **e071 (diagnostic) profiled stage table of 108bd50f + e067 overrides (STRATA_VERIFY_PROFILE=1): 30.64; request 3
  a PLE stall (`stage 110.68` ms/window).** Request 1 (104 windows, T 3.18), ms/window, total 74.46:
  | stage | GDN | QSA | sum | vs e018 (it. 4) |
  |---|---|---|---|---|
  | routed experts (VRAM hits) | 17.07 | 5.33 | **22.40** | 24.5 |
  | dense: qkv 6.95, z 3.89, out-proj 4.11 / q 2.96, out-proj 1.40, k/v 0.55 | 14.95 | 4.91 | **19.86** | 22.75 |
  | HC: hc-read1+router 5.90/1.97, hc0 norm 0.96/0.10, down 2.30/0.76, up 2.00/0.67 | 11.16 | 3.50 | **14.66** | 16.1 |
  | head | 4.42 | - | **4.42** | 5.40 |
  | shared+quant (serialized by the profiler) | 3.08 | 1.03 | **4.11** | 4.14 |
  | QSA attention (mostly the q GEMV wait) + scores | - | 4.47 | **4.47** | 4.47 |
  | rec/conv/ab | 2.11 | - | 2.11 | 2.0 |
  | waitA/B/CPU + copy+combine + PCIe grp + gap | 1.53 | 0.54 | **2.07** | - |
  Bandwidth now: experts ~125 GB/s, dense ~100, HC ~70 (1.04 GB in 14.7 ms), head ~118; DRAM 180 (p037).
  shared+quant reads ~95 MB in 4.1 ms (~23 GB/s) but runs on its own stream when not profiled, so most of it hides.
- Iteration 13 used 5 runs (e067-e071). Commit 108bd50f on ar/decode-speed. Tree clean.

### iteration 14 (2026-11-01 ~07:12-), e072-
Pairing reference: e070 78.66 / 81.38 / 75.67 ms/window (e067 78.41 / 81.17 / 75.49), windows 103/100/107.
- **e072 (env) STRATA_DF_BRANCH=1** (verify.cpp:1278, never tried here: GDN a/b + z GEMV on side streams beside
  qkv + conv, QSA q and indexer q beside k/v; fork/join events inside the graph): **30.47, texts = e015
  1.0/1.0/1.0; 81.56 / 84.51 / 78.20 = +2.5 to +3.1 ms/window. Much slower.** Two causes: the side-stream z / q call
  native_mmvq (not the IL kernel), and two GEMVs at once only compete for the 16 SMs (each already fills them).
  Concurrency of decode kernels does not pay on Orin. Do not retry.
- **e073 (env) STRATA_MMVF_ROWS=1** (BF16 router 512 x 2560 + QSA indexer q/k GEMVs at 4 rows a block, activations
  read once a block; the kernel's contract says bitwise): **31.19, texts 1.0; 79.69 / 82.56 / 76.70 = +1.0 to
  +1.2 ms/window. Slower**: 128 blocks instead of 512 for the router. Same lesson as e064: on 16 SMs, fewer blocks
  lose more than the L2 re-reads cost. Do not retry.
- **e074 (code, kept) opt-in STRATA_HIT_COMBINE=1**: verify.cpp post() skips copy_rows_from_mapped (zero-fill of the
  GPU rows + the CPU rows from mapped) and moe_hit_add; native_moe.cu `combine_k10_vec4_hits_mapped` reads a row in
  p_dst[0, count) as `0.0f + hit` and any other from the mapped CPU rows, then runs combine_k10_vec4's code. The add
  is inline PTX `add.rn.f32` without .ftz: native_moe.cu builds with --use_fast_math (ftz), s2_expert_grouped.cu
  (add_hits_kernel) without, so a plain `0.0f + h` here would flush a denormal hit the old path kept (the existing
  native_moe_combine_multi_hits, used by the all-resident path, has that gap). 2 launches + ~1.3 MB of traffic a
  layer fewer. **31.77 (31.63-31.78), texts = e015 1.0/1.0/1.0; 78.22 / 80.93 / 75.31 ms/window = -0.27 to -0.35
  vs the e067/e070 mean.** Small, real (~3x the e067-e070 repeat spread of 0.2), bitwise by construction.
- **e075 (code, reverted) opt-in STRATA_ATTN_PF=1 on e074**: qsa_decode_attn.cu attn_chunk_kernel with the score
  phase loading two cells' keys per warp before scoring them and the value phase four cells' values before their
  FMAs (only loads move): **31.65, texts 1.0; 78.53 / 81.22 / 75.59 = +0.28 to +0.31 vs e074. Slower.** QSA
  attention is 3.85 ms/window (10 layers, cap 2051 cells = 33 chunks x 2 KV heads x T blocks of 256), ~17 GB/s:
  it is not waiting on its loads; the 12 heads x 5-shuffle warp sums per cell (score phase) or the 12 LDS + 12 FMA
  per cell (value phase) are the likely cost. Source: runs/e075-attn-pf/source.diff. The bitwise lane-cell variant
  (STRATA_ATTN_LANECELL) was slower in e006 (5.14 vs 3.59).
- **e076 = e074 again + needles (ATTN_PF code reverted, it was inert): 31.69 (31.53-31.70), needles 3/3, texts =
  e015 1.0/1.0/1.0; 78.44 / 81.18 / 75.47 ms/window.** e074 ran ~0.2 fast; the needle-run pair e076 vs e070 is
  -0.22 / -0.20 / -0.20, so the HIT_COMBINE gain is ~0.2 ms/window. min avail 8.7 GiB. **Committed c65c86ee**
  (e074's code). +0.83 / +0.71 over e059/e060: below the 1.7 bar, e059/e060 stays the formal best.
- **Lessons this iteration:** on Orin's 16 SMs, every change that lowers the block count (e073, e064) or runs two
  GEMVs at once (e072) loses; launch removal pays ~4-5 us a many-block launch (e067, e074); load reordering in a
  kernel that is not waiting on loads loses (e075, also e038/e039).
- Iteration 14 used 5 runs (e072-e076). Commit c65c86ee on ar/decode-speed. Tree clean.

### iteration 15 (2026-11-01 ~07:33-08:05), e077-e080
Pairing reference: e076 78.44 / 81.18 / 75.47 ms/window, draft 6.12 / 6.39 / 5.73 (windows 103/100/107).
- **The tree already had a bitwise faster QSA decode attention kernel, gated off on CUDA**: qsa_decode_attn.cu
  `attn_chunk_kernel_pre75` (PR #540, "bit for bit the kernel above"), built on CUDA only with
  -DSTRATA_EXPERIMENTAL_SM60 and run only below sm_75 (HIP gfx103x runs it with 8 cells + DPP). Score phase: the 12
  head sums of a cell are reduce-scattered (`reduce12`: at xor 16 a lane keeps 8 heads and adds the partner's copy,
  at 8 four, ... = the same operand pair at every level as warp_sum's xor-16..1 butterfly; fp add commutes) =
  16 shuffles a cell instead of 12 x 5 = 60; 2 cells a step share the q reads from smem; probabilities stored
  cell-major (the same values); V folded over the cells in the same ascending order (4 loads issued together).
- **e077 (code, kept) build it for every CUDA card, `STRATA_ATTN_PRE75=1` selects it on sm_75+ (default unchanged):
  32.46 (32.38-32.49), texts = e015 1.0/1.0/1.0; 76.56 / 79.07 / 73.64 ms/window = -1.88 / -2.11 / -1.83 vs e076**
  (verify -1.7, draft -0.2: the MTP layer's attention takes the same kernel). The attention kernel was a much
  bigger cost than e075's +0.3 suggested: its score phase was shuffle-bound, not load-bound.
- **e078 (env) STRATA_ATTN_NC=1 (1 cell a score step; added for the A/B, removed): 32.12, texts 1.0; 77.25 / 79.93 /
  74.48 = +0.7 to +0.85 vs e077.** e079 NC=4: 32.43, texts 1.0; 76.60 / 79.27 / 73.77 = +0.04 to +0.2. **NC 2 is the
  optimum on Orin** (same as the V100 measurement).
- **e080 = e077 again + needles: 32.52 (32.41-32.54), needles 3/3, texts 1.0; 76.38 / 78.98 / 73.57 (e077 within
  0.2).** min avail 8.68 GiB. Registers (new BW-probe lines, kept): default attn_chunk_kernel q8 40 / 6 blocks of
  256; pre75 nc1 59 / 4, **nc2 64 / 4**, nc4 97 / 2; a `__launch_bounds__(256, 4)` copy of nc2 = 64 + 16 B local
  (spill) -> not run (no headroom: nc2 already sits at 4 blocks). Committed **07c4d793** (e077's kernel code + the
  print; the NC / LB4 A/B code removed).
- **Lesson: grep for arch-gated fast paths.** This gain was sitting behind an `#if` for another card generation.
  Other gated variants (`cc < 75`, STRATA_EXPERIMENTAL_*, HIP-only paths with a CUDA form, "until the A/B says
  otherwise" opt-ins) are cheap one-run A/Bs; check each one's bitwise claim in its comment first.
- Iteration 15 used 4 runs (e077-e080). Commit 07c4d793 on ar/decode-speed. Tree clean.

### iteration 16 (2026-11-01 ~07:55-08:25), e081-e085
Pairing reference: e080 76.38 / 78.98 / 73.57 ms/window, draft 5.85 / 6.12 / 5.49 (windows 103/100/107).
- **Gated-path sweep (iteration-15 item 1) is exhausted for the decode path.** Read and ruled out: router_top10.cu's
  HIP "S6" bit-identical router (CUDA decode already runs native_router.cu `route_multi`, one warp a token, via
  verify.cpp:2121); STRATA_EXP_MODE layouts 1-8 (different lane split per row = another sum order, and forced to mode 0
  anyway under VRAM_GY strides, iq_kernels.cu:3531); STRATA_GR_V3 ("another summation order"); STRATA_SM70_TABLE
  (Volta only); STRATA_FUSE_HEAD_GR (last layer only); arch_defaults.cpp tables (all tried in e006/e017/e072/e073).
  Only two untested bitwise env switches were left: GDN_SPLIT and DF_PLE (e083, e084 below).
- **e081 (code, reverted) opt-in STRATA_Q6_AL=1: Q6_K IL kernel + 1-column warp kernel read ql/qh as one 32-bit word
  on 4-byte-aligned blocks (every other 210-byte block) via a run-time pointer test per block: 30.01, texts = e015
  1.0/1.0/1.0; 82.73 / (91.78, a small stall) / 79.71 ms/window = +6.1 to +6.4.** Lesson: a branch per block inside
  the 4x-unrolled block loop stops the compiler issuing the 4 blocks' loads together (ILP lost); never put a
  data-dependent branch in those loops.
- **e082 (code, reverted) the same with the parity fixed at compile time (kbx = m0 + v, m0 a multiple of 4; host takes
  it only for an aligned matrix with an even block count): 32.11, texts 1.0; 77.40 / 80.14 / 74.40 = +0.8 to +1.2.**
  Draft unchanged (warp kernel 38 registers either way, so the aligned loads are worth ~0 there); IL al nc3 r1 fell
  to 56 registers / 9 blocks (e052's losing setting), nc4 r2 94 -> 126 / 4 blocks. **Weight-load instruction count
  does not limit the Q6_K kernels** (same lesson as e038/e039/e043 for loads). Source:
  runs/e082-q6-al-static/source.diff. Do not retry.
- **e083 (env) STRATA_GDN_SPLIT=1: 32.48, texts 1.0 (bitwise on sm_87 too); 76.53 / 79.13 / 73.65 = +0.08 to +0.15:
  neutral.** Drop.
- **e084 (env) STRATA_DF_PLE=1: 32.46, texts 1.0; 76.50 / 79.17 / 73.71 = +0.12 to +0.19: neutral.** Drop. (Not
  checked whether ple_batch_kv was true, i.e. whether the switch was active.)
- **e085 (diagnostic) profiled stage table of 07c4d793 + e077 overrides: 31.61 (profiled). Request 1 (104 windows,
  T 3.18), ms/window, total 72.52 (e071: 74.46):**
  | stage | GDN | QSA | sum | vs e071 |
  |---|---|---|---|---|
  | routed experts (VRAM hits) | 16.95 | 5.30 | **22.25** | 22.40 |
  | dense: qkv 6.99, z 3.90, out-proj 4.10 / q 2.98, out-proj 1.40, k/v 0.56, q8 0.15 | 14.99 | 5.09 | **20.08** | 19.86 |
  | HC: hc-read1+router 5.87/1.97, hc0 norm 0.97/0.10, down 2.27/0.76, up 2.02/0.67 | 11.13 | 3.50 | **14.63** | 14.66 |
  | head | 4.46 | - | **4.46** | 4.42 |
  | shared+quant (serialized by the profiler; hidden on its own stream otherwise) | 3.09 | 1.04 | **4.13** | 4.11 |
  | QSA attention 2.24 + scores+topk 0.61 | - | 2.85 | **2.85** | 4.47 |
  | rec 1.38, conv 0.25, ab 0.47 | 2.10 | - | 2.10 | 2.11 |
  | waits + copy+combine + PCIe grp + gap | 1.36 | 0.48 | **1.84** | 2.07 |
  The pre75 kernel took QSA attention from ~3.86 to 2.24; nothing else moved. Ranking by distance from the DRAM's
  ~180 GB/s: HC (~70 GB/s, ~8 ms above a 180 GB/s read), dense (~100, ~7.5), experts (~125, ~6), head (~118, ~1.5).
- Note: the GDN "hc0 norm" (0.97 = 32 us a layer vs 10 us on QSA layers) includes layer 1's PLE block (verify.cpp
  pre(), between stamp 0 and the HC down), so ~0.6 ms/window of it is PLE work, not the norm. DF_PLE did not cut it.
- Iteration 16 used 5 runs (e081-e085). No commit; the e081/e082 code was reverted by hand (git checkout is still
  denied); `git status --short` clean.

### iteration 17 (2026-11-01 ~08:20-08:45), e086-e089
Pairing reference: e080 76.38 / 78.98 / 73.57 ms/window, draft 5.85 / 6.12 / 5.49 (windows 103/100/107).
- Shapes (iq_kernels.cu): gate/up = 1280 rows (2 x n_ff 640) of 1100 B (IQ3_S, K 2560), 16 rows a block (16 lanes a
  row), 80 x GY blocks; down = 2560 rows of 360 B (IQ4_NL, K 640), 32 rows a block (8 lanes a row). A block's rows
  are one contiguous slice: 17.6 KB (gate/up) / 11.5 KB (down) a group, and at GY 8 a block walks ~3-4 groups with
  a cold DRAM start on each.
- **e086 (code, kept) opt-in STRATA_EXP_PF=1: native_gu_multi_kernel (SUB16 path, IQ3_S) and
  native_down_multi_kernel (sub8 path, IQ4_NL) issue `prefetch.global.L2` for the block's slice of its first group
  at start and of group g + gridDim.y at the top of group g, one per 32-byte sector over the 256 threads (~2 a
  thread a group).** A cache hint: nothing else in the kernels changes. Registers unchanged (gate/up 48 / 5 blocks,
  down 64 / 4, no new local). **32.68 (32.58-32.71), texts = e015 1.0/1.0/1.0; 76.00 / 78.59 / 73.22 ms/window =
  -0.38 / -0.39 / -0.35 vs e080** (all in verify; draft unchanged). Committed 93c74af5.
- **e087 = e086 again + needles: 32.67 (32.57-32.69), needles 3/3, texts 1.0; 76.03 / 78.60 / 73.23 (e086 within
  0.03).** min avail 8.67 GiB. **New formal best** (+1.74 / +1.73 over e059).
- **e088 (code, reverted) opt-in STRATA_IL_PF=128: each warp of native_mmvq_il_kernel (dense GEMVs at 2-4 columns +
  verify head) L2-prefetches the rows of its counterpart warp 128 blocks ahead (~one wave of resident blocks):
  31.71, texts 1.0; 78.38 / 80.96 / 75.42 = +2.2 to +2.4 ms/window. Much slower.** Confound: the pf build put Q6_K
  nc3 r1 at 56 registers / 9 blocks (e052's losing setting, +1.2-1.6 alone); nc4 r1 (62 / 8) and r2 (93 / 5) kept
  their occupancy, so the prefetch traffic itself likely costs the rest (~+1). The dense warps read their whole row
  in one m0 pass, so there is no within-warp lookahead to win, and one-wave-ahead traffic competes with the demand
  reads. Source: runs/e088-il-pf128/source.diff. Do not retry one-wave-ahead prefetch in the dense GEMVs.
- **e089 (env) e086 + STRATA_VRAM_GY=4: 32.67, texts 1.0; 76.05 / 78.66 / 73.23 = e086 within 0.07: neutral.**
  Without PF GY 4 was +0.1-0.2 vs GY 8 (e061), so PF gains a little more at GY 4 (more groups prefetched ahead)
  but the net is the same. GY 8 stays.
- Lessons: L2 prefetch pays where a warp/block walks several **dependent, cold** chunks in sequence (the grouped
  experts: next group known one group ahead) and costs nothing in registers; it does not pay where every warp reads
  its data in one pass (dense GEMVs). HC down already double-buffers one tile ahead (e038: not weight-latency bound),
  so it is not a candidate.
- Harness: `git checkout -- <file>` still denied; e088 reverted by hand with Edit, `git status --short` clean.
- Iteration 17 used 4 runs (e086-e089). Commit 93c74af5 on ar/decode-speed. Tree clean.

### iteration 18 (2026-11-01 ~08:40-), e090-
Pairing reference: e087 76.03 / 78.60 / 73.23 ms/window, draft 5.84 / 6.11 / 5.47 (windows 103/100/107), 7831 /
7860 / 7836 ms per 256 tokens.
- **e090 (settings) e086 stack + `--mtp-hnorm stream`** (generate.cpp:924: the draft layer's pre_fc_norm_hidden as
  one RMS per hyper-connection stream, llama.cpp's MTP graph, instead of one pooled RMS over all four; touches only
  the drafter: mtp.cpp:742 and the drafter's prompt pass, prefill.cpp:1420). **32.68 (32.68 / 29.20 / 35.20),
  texts = e015 1.0/1.0/1.0 (PASS: drafting policy; NB the result.json "gate" 0.136 is vs the old baselines, as in
  every run since e015 — always run compare.py vs e015).** Drafts accepted 153/213, 157/209, 158/200 (72-79%) vs
  e087 154/225, 159/237, 149/213 (66-70%): the per-stream norm drafts more precisely, so fewer columns per window
  (T 3.03 / 3.11 / 3.04 vs 3.18 / 3.37 / 2.99) and draft 5.57-5.70 vs 5.47-6.11 ms/window. Per request (ms per 256
  tokens): req 1 105 x 74.61 = 7834 vs 7831 (neutral), **req 3 98 x 74.21 = 7273 vs 7836 (-7.2%)**, req 2 had a
  CPU-expert stall (`per-layer host 15.05 [CPU 14.80]`, 88.54 ms/window; GPU-reach wait 62.80 vs e087's 65.08):
  without it ~99 x 74.7 = ~7400 (-6%), i.e. a stall-free median ~34.6. Needs a repeat (e092).
- **e091 (code, reverted) opt-in STRATA_DOWN128=1: the IQ4_NL sub8 expert down as a 128-thread, 16-row-a-block
  kernel under `__launch_bounds__(128, 9)`: 56 registers, 0 B local, 9 blocks of 128 = 36 warps a SM (was 64 / 4 x
  256 = 32). 32.50 (32.39-32.53), texts = e015 1.0/1.0/1.0; 76.40 / 79.03 / 73.62 ms/window = +0.37 / +0.43 / +0.39
  vs e087. Slower.** Third time 56 registers / 9 blocks of 128 loses (e052 IL rows 1, e082 Q6_K aligned IL, now
  down): more warps at a 56-register cap do not pay on Orin; the down kernel stays at 64 / 4 x 256. Do not retry
  occupancy caps on the expert kernels. Source: runs/e091-down128/source.diff.
- **e092 = e090 again + needles: 34.09 (32.69 / 34.09 / 35.22), needles 3/3, texts = e015 1.0/1.0/1.0, no stall.**
  Per request 105 x 74.59 = 7832 / 99 x 75.85 = 7509 / 98 x 74.18 = 7270 ms vs e087 7831 / 7860 / 7836 = **0.0 /
  -4.5 / -7.2%**; requests 1 and 3 reproduce e090 within 0.03 ms/window, drafts 153/213, 157/211, 158/200. min avail
  8.68 GiB. **+1.41 over e086's 32.68: below the 1.7 bar, so e086/e087 stays the formal best; e092 is the leading
  candidate (PASS: drafting policy, settings only, nothing to commit).** The gain is prompt-dependent (prompt 1
  gains nothing): the per-stream drafter offers ~6-12% fewer drafts and gets the same accepted count. Mechanism
  check: at the same verify windows' cost line (~40 + 12.5 ms per column), T 3.03 vs 3.18 is worth ~1.9 ms/window.
- **e093 (settings) e092 + `--spec-min-p 0.4`: 34.37 (32.34 / 34.63 / 34.37), texts = e015 1.0/1.0/1.0; per
  request 102 x 77.60 = 7915 / 92 x 80.35 = 7392 / 95 x 78.41 = 7449 ms vs e092 7832 / 7509 / 7270 = +1.1 / -1.6 /
  +2.5% (sum +0.6%). Not kept: the median is higher only by request order.** The 0.4-0.5 confidence band added
  21 / 21 / 29 drafts and 3 / 9 / 3 accepted (14 / 43 / 10%), below the ~35% a marginal draft needs (12.5 ms verify
  column + ~2 ms draft step vs ~30 ms a token). min-p 0.5 stays with the stream drafter too.
- Iteration 18 used 4 runs (e090-e093). No commit (e091's code reverted by hand, `git status --short` clean; the
  e090/e092 gain is a command-line setting). Harness: `git checkout -- ...` still denied.

### iteration 19 (2026-11-01 ~08:59-), e094-
Pairing reference: e092 7832 / 7509 / 7270 ms per 256 tokens (105 / 99 / 98 windows, 74.59 / 75.85 / 74.18
ms/window, draft 5.58 / 5.71 / 5.62).
- **e094 (settings) e092 + `--spec-min-p 0.6`: 33.53 (30.61 / 33.77 / 33.53), texts = e015 1.0/1.0/1.0; per request
  109 x 76.74 = 8364 (a CPU-expert stall: per-layer host 6.56 [CPU 6.37]) / 104 x 72.90 = 7581 / 111 x 68.79 = 7635
  ms vs e092 7832 / 7509 / 7270 = +6.8 (stall) / +1.0 / +5.0%. Worse; min-p 0.5 stays.** Drafts accepted 148/191,
  154/196, 145/175 (77-83%): cutting the 0.5-0.6 band drops ~4-13 accepted drafts a request, so that band pays
  above break-even. With e093 (0.4 worse) the stream drafter's min-p is settled at 0.5. Draft vocab 49152/full was
  not run: e019 showed the first 40960 entries hold every token these essays draft (same accepted counts as the
  full head), so a bigger subset can only add head bytes.
- HC down shape (fused_gr.cu): 320 `lo` rows + 4 inject rows of 10240 bf16 (20 KB each), one warp a row, 8 rows a
  block = 41 blocks; **the BW-probe print says T3 (the most common window) runs 84 registers = 2 blocks of 256 a SM
  = 32 slots for 41 blocks: two waves** (T1/T2/T4 get 3 a SM). At 3 a SM (e056's cap) the busiest SMs still hold
  24 rows (9 SMs x 3 blocks) vs 16 on the other 7, which is why that cap was neutral.
- **e095 (code) opt-in STRATA_HC_DOWN_WPB=21: the staged HC down as gr_down_bal_kernel, 21 warps a block, 16 blocks =
  one a SM (<= 21 rows a SM), 16 instead of 41 blocks staging the activations. Each row is still one warp with the
  same lanes, tiles, order and xor tree (bitwise by construction; the startup self-test ran it through the staged
  path and accepted it "bit for bit against the plain read"). 34.27 (32.86 / 34.27 / 35.41), texts = e015
  1.0/1.0/1.0; 74.19 / 75.45 / 73.77 ms/window = -0.40 / -0.40 / -0.41 vs e092 (same windows 105/99/98, all in
  verify).** Registers at the 672-thread bound: T1 66, T2 80, T3 80 + 8 B local, T4 80 + 16 B local. +0.18 over
  e092: still below the 34.38 bar alone.
- **e096 (code) e095 + opt-in STRATA_HC_UP_PF=48: gr_up_fast_lr_kernel (HC up: 160 blocks of 64 rows, 80 regs / 3 a
  SM = 48 slots, 3.33 waves; each block loads its 40 KB, then computes) as gr_up_fast_lr_pf_kernel: each block
  prefetch.global.L2s the weights of block blockIdx.x + 48 (~one wave later; 4 x 10 KB, 5 sectors a thread). Cache
  hint only, registers unchanged (80 / 3 a SM, 0 local). 34.40 (33.00 / 34.40 / 35.55), texts = e015 1.0/1.0/1.0;
  73.88 / 75.16 / 73.48 ms/window = -0.31 / -0.29 / -0.29 vs e095 (-0.71 / -0.69 / -0.70 vs e092).** Per request
  105 x 73.88 = 7757 / 99 x 75.16 = 7441 / 98 x 73.48 = 7201 ms vs e087 (formal best) 7831 / 7860 / 7836 = -0.9 /
  -5.3 / -8.1%. **+1.72 over e086's 32.68: just clears the 1.7 bar; needs the repeat.** Unlike e088 (dense IL
  one-wave-ahead prefetch, +2.2 ms), this one pays: an up block is load-all-then-compute in lock-step waves, so
  the DRAM idles during each wave's compute unless the next wave's bytes are already requested.
- **e097 (code, reverted) e096 + opt-in STRATA_HC_DOWN_PF=2: in gr_down_bal_kernel each warp L2-prefetches its
  row's tile h+3 at the top of tile h (the register lookahead loads h+1). 34.18, texts 1.0; 74.41 / 75.65 / 74.03
  ms/window = +0.53 / +0.49 / +0.55 vs e096. Slower.** Registers T3 80 + 16 B local (was 8 B). Third time a deeper
  lookahead in HC down fails (e038 registers, now L2): its warps are not waiting on their weights. Source:
  runs/e097-hcdown-pf2/source.diff. Do not retry. Code removed by hand (tree = e096's source).
- (e098 ran at the end of iteration 19 but was recorded in iteration 20, below.)

### iteration 20 (2026-11-01 ~09:35-10:10), e099-e100
Pairing reference: e096 73.88 / 75.16 / 73.48 ms/window, e098 74.12 / 75.36 / 73.73 (windows 105 / 99 / 98).
- **e098 = e096 again + needles (run by iteration 19, recorded here): 34.31 (32.89 / 34.31 / 35.43), needles 3/3,
  texts = e015 1.0/1.0/1.0; 74.12 / 75.36 / 73.73 ms/window (e096 + 0.20-0.25); 7783 / 7461 / 7225 ms per 256
  tokens.** min avail 8.65 GiB. The tree held e096's source uncommitted (git diff = runs/e098-hc-confirm/source.diff
  byte for byte): **committed as 0613c7a2.** +1.63 over e086: the repeat misses the 1.7 bar by 0.07.
- **e099 (code, reverted) opt-in STRATA_MMVF_PF=96: bf16_f32_mmvf_multi_kernel<256, 2..4> (BF16 router 512 one-row
  blocks, QSA indexer q/k) L2-prefetches the row of block blockIdx.x + 96: 34.38 (32.96 / 34.38 / 35.52), texts =
  e015 1.0/1.0/1.0; 73.98 / 75.22 / 73.54 = -0.02 to -0.07 vs the e096/e098 mean: neutral.** The kernel runs 56
  registers / 4 blocks of 256 a SM (64 resident, 8 waves for 512 rows), so 96 was 1.5 waves ahead. The router GEMV
  is not waiting on DRAM between waves (unlike HC up). Source: runs/e099-mmvf-pf96/source.diff. Do not retry.
- **e100 (diagnostic, committed 3f76f45d, profiler only): STRATA_VERIFY_PROFILE now splits the VRAM hits (new stamp
  32 in native_expert_grouped after gate/up + SwiGLU) and hc-read1+router (read 1's own stamps 30/31, which the
  profiler never summed). 33.34 profiled, texts = e015 1.0/1.0/1.0. Request 1 (105 windows, T 3.03), ms/window:**
  | stage | GDN | QSA | sum |
  |---|---|---|---|
  | experts gate/up + SwiGLU | 10.51 | 3.25 | **13.76** |
  | experts down | 5.61 | 1.79 | **7.40** |
  | dense: qkv 6.91, z 3.90, out 4.11 / q 2.95, out 1.42, k/v 0.55, q8 0.15 | 14.92 | 5.07 | **19.99** |
  | hc0 norm / down / up | 0.96 / 2.07 / 1.97 | 0.10 / 0.69 / 0.65 | **6.44** |
  | hc1 norm / down | 0.28 / 2.04 | 0.10 / 0.69 | **3.11** |
  | hc1 up + router GEMV + top10 + doorbell | 3.27 | 1.09 | **4.36** |
  | head | 4.46 | - | 4.46 |
  | shared+quant (serialized by the profiler) | 3.03 | 1.01 | 4.04 |
  | attention 2.15 + scores/topk 0.61, rec 1.38, conv/ab 0.68, waits/combine ~1.9 | | | ~6.7 |
  Total 70.48. Readings: (1) **gate/up is the weak expert kernel**: per routed entry it reads 1.4 MB vs down's
  0.92 MB (1.52x) but takes 1.86x the time (~122 vs ~149 GB/s on the entry count, upper bounds since entries repeat).
  Bringing gate/up to down's rate is worth ~2.5 ms/window, the largest single target left. (2) hc1 norm 0.28 vs hc0
  norm 0.96 on GDN layers: ~0.68 ms/window of "hc0 norm" is layer 1's PLE block, confirmed. (3) hc1 up + router +
  top10 + doorbell minus hc0 up = 1.30 (GDN) + 0.44 (QSA) = **~1.74 ms/window, ~43 us a layer**, of which the router's
  2.6 MB is ~17 us at 150 GB/s: top-10 (route_multi, one warp a token) + the doorbell (one 1024-thread block, a
  read-modify-write of the mapped seq, x copied only on a miss) + launch gaps are ~25 us a layer.
- Harness: `git checkout -- <file>` still denied; e099 reverted by hand with Edit, `git status --short` clean.
- Iteration 20 used 2 runs (e099, e100) + the e098 bookkeeping. Commits 0613c7a2, 3f76f45d on ar/decode-speed.

## Ranked next steps (edit as you learn)
Base for all new arms: overrides/e015-pin14629-grfast.json (kv-grow + `--expert-cache 14629` + STRATA_GR_FAST=1).
Gate = `python3 compare.py runs/<exp>/result.json runs/e015-pin14629-grfast/result.json` must be 1.0/1.0/1.0
(text depends only on placement on this build: e014 = e012, e015 = e007), plus paired ms/window per request from
the `decode timing` lines (same texts -> same windows -> a clean paired A/B, resolves ~1% effects).
(iteration 4) **New base: overrides/e021-pin-grfast-dvocab40k-q6il.json** (e015 + DRAFT_VOCAB_TOP=40960 + the
Q6_K IL rows; e022's 16384 lost); the text reference stays e015 (e017-e022 all = e015 bitwise). Profiled arms
pair with e018 (base) / e020 (IL rows) stage tables (same texts and windows).
(iteration 5) e021 stays the base; its level reproduced in e026 (28.76). Switch tuning is close to exhausted: IL
rows (e023/e024/e026), cache size (e027), spec 3 (e028), min-p (e014), resident budget (e025 abort) are done.
(iteration 6) **Base: commit 9b87a9c0 + overrides/e021-pin-grfast-dvocab40k-q6il.json** (e031/e033, 29.1-29.2).
Text reference stays e015 (every arm since e017 = e015 bitwise); pair ms/window per request against e031/e033
(85.0-85.3 / 87.8-87.9 / 81.9-82.1 at windows 103/100/107). spec 5 (e029) and IL for 5-6 columns (e030) are done:
spec 4 windows never exceed 4 tokens, spec 5 loses.
(iteration 7) **The DRAM streams ~180 GB/s (p037); every decode kernel is at 83-120 GB/s.** Kernel work has real
headroom. Profiled reference for the current build: runs/e035-profile-il4 (rows 4 at classes 2-4; for the other
stages it equals the base) or e024 for the dense stages at rows 2. Bitwise only: keep each output's per-lane order
and reduction tree, then check compare.py vs e015 = 1.0 and pair ms/window against e031/e033/e036 (84.8-85.3 /
87.5-87.9 / 81.7-82.1 at windows 103/100/107).
(iteration 8) **The memory side is ruled out (p041/p042): GEMV-pattern reads of the decode kernels' sizes run at
146-177 GB/s in a graph; the kernels run at 83-120. Treat every decode kernel as instruction-issue bound.** Judge
kernel ideas by instructions removed per weight byte (and registers: e039 shows extra live registers cost more than
they hide), not by loads in flight. Base and pairing unchanged (e031/e033/e036 ms/window at windows 103/100/107).
(iteration 9) **Base: commit 241e3e25 + overrides/e021-pin-grfast-dvocab40k-q6il.json** (e047/e048, 29.77).
Pair against e048: 83.48 / 86.06 / 80.29 ms/window, verify 76.77 / 79.03 / 74.00, GPU-reach wait 69.80 / 71.24 /
67.32, draft 6.68 / 6.99 / 6.26 (windows 103/100/107). Overrides with `"STRATA_BW_PROBE": "1"` (e044's file) print
the registers/occupancy table at start; it costs nothing measurable in decode. Step 0 below is superseded: the
clock is 1.29 GHz (not the cause), and occupancy, not instruction count, is what moves the kernels.
(iteration 10) **Base: commit cda89788 + overrides/e044-q6il-noi2f-clk.json** (e053/e054, 30.4-30.5). Pair against
e053: 81.43 / 84.16 / 78.53 ms/window (windows 103/100/107). Done: IL rows-1 cap (8 blocks is the optimum: 7 and 9
both lose ~1.5 ms), IL rows-2 cap (neutral), down kernel at (256, 5) (spills, slower), lane_pick (kept).
(iteration 11) **Base: commit c6f7ca32 + overrides/e059-vram-gy8.json** (e059/e060, 30.94-30.98). Pair against
e059: 80.15 / 82.75 / 77.35 ms/window, GPU-reach wait 66.77 / 68.20 / 64.57 (windows 103/100/107); text reference
still e015. Done this iteration: occupancy of every HC kernel (a. below: the caps spill or do not help), IL rows 1
everywhere (neutral). **Next, in order:**
  1. **STRATA_VRAM_GY=4, then 2** (env only, one arm each): 16 -> 8 gained another 0.5 ms; find where the curve
     turns (fewer blocks = fewer per-block overheads but a coarser tail: 4 = 320 blocks a launch, 5 waves at
     4-5 blocks a SM). Then the same stride for the PCIe call (kPcieGroupRows, inert at pcie 0.00) is moot.
  2. **The same idea inside each block**: native_down_multi_kernel / native_gu_multi_kernel stage and barrier per
     entry chunk per group; with gy small a block walks ~3 groups one after another. Prefetch the next group's
     weights (same values, same per-lane order) before the barriers, or stage the next group's hq while the current
     one computes (double buffer: one barrier per group). Bitwise if each row's dot is unchanged.
  3. Other launches sized for a cap that mostly exit: grep the decode path for grids sized by cap_entries / max_t_
     whose blocks read a device count and return (swiglu_entries / quantize over cap_entries x n_ff, moe_hit_add,
     the shared expert); same stride trick where a loop already exists.
  4. HC up (127 registers, 2 blocks a SM, ~5.5 ms/window over both reads): only with the unpack recomputed per
     token (dot8v on packed weights inside the token loop) so it fits 80 registers without spilling; the compiler
     may hoist it again (check the BW-probe register/local print). e031's gain must not be undone (activations read
     once for both rows).
  5. One-column kernels (draft ~6.7 ms/window: Q8_0 MTP dense 111 MiB + Q6_K draft head 82 MiB a step, 1 row a block
     of 4 warps): a warp-a-row kernel that keeps the 4-warp sum order ((t0 + t1) + t2) + t3 per lane, then the same
     warp_sum. ~0.5-1 ms/window at best.
(iteration 12) **Base: the e065 build (gr_up_fast_lr_kernel + warp-a-row 1-column GEMVs, both opt-in) +
overrides/e065-mmvq1-warp.json** (= e059's file + STRATA_GR_UP_LR=1 + STRATA_MMVQ1_WARP=1). Pair against e065:
79.37 / 82.11 / 76.42 ms/window, draft 6.19 / 6.47 / 5.81, GPU-reach wait 66.58 / 68.10 / 64.24 (windows
103/100/107). Done this iteration: VRAM_GY 4 (e061, neutral: 8 is the optimum), down kernel without its hq staging
(e062, neutral), 1-column GEMVs at 4 rows a block (e064, +0.6 slower). **Next, in order:**
  1. **Q8_0 warp-a-row kernel at full occupancy**: native_small_mmvq_warp_kernel is 63 registers / 8 blocks (the
     Q6_K one 38 / 12). Try `__launch_bounds__(WARPS * WARP, 12)` (<= 40 registers) or `#pragma unroll 1` / 2 on
     its v loop (each t[v] keeps its blocks in the same order either way: bitwise); reject on local bytes. The MTP
     dense is 111 MiB a step, so this is worth up to ~0.3 ms/window.
  2. **The PCIe grouped call per layer is 3 empty launches** (gu, swiglu, down with n_groups 0: "PCIe grp" 0.33 +
     0.11 ms/window in e035's profile). expert_source.cpp:3356 gives the PCIe share `(nmiss * pcie_num) >> 8`
     experts, pcie_num 141 at frac 0.55, so one miss in a layer-window never goes PCIe (why PCIe is 0.00).
     Step a: `--pcie-frac 0` alone, texts vs e015 (placement only; PASS if 1.0). Step b: with pcie_num 0 known at
     capture, skip verify.cpp's `grouped(p_ptr2, ...)` (+ the pcie_mode 2 fetch); keep the flagB wait. Mind the
     per-request `pcie_frac` key (generate.cpp:9552): with the skip on, refuse or ignore a request's nonzero value.
  3. **A profiled stage table of the current stack** (e065 overrides + STRATA_VERIFY_PROFILE=1): the last one (e035)
     predates every kernel change since iteration 7. Pick the next kernel from it.
  4. Gate/up: load the next group's grp_ptr / grp_start while computing the current one (a block walks ~3 groups at
     GY 8); <= 4 more registers at the 48-register cap (check local bytes). ~0.2-0.5 ms at best.
  5. The other big stages, unchanged since iteration 9: experts ~21 ms (~127 GB/s of ~180), dense ~19 ms, HC ~14 ms
     (down is done: e032/e038/e057/e062-style ideas all neutral), head ~5.3 ms (97 GB/s).
(iteration 13) **Base: commit 108bd50f + overrides/e067-nopcie-q8lb.json** (e067/e070, 31.6-31.7). Pair against
e070 (the slower of the two, closer to the mean): 78.66 / 81.38 / 75.67 ms/window, verify 72.54 / 74.98 / 69.94,
draft 6.09 / 6.36 / 5.70 (windows 103/100/107); text reference still e015. Profiled reference: e071's table above.
Done: iteration-12 items 1 (Q8_0 cap, e067) and 2 (PCIe launches, e067); flag-wait fusions (e068) and the flagB skip
(e069) are neutral or worse: do not retry. **Next, in order:**
  1. **Many-block launches that mostly exit** (the e067 lesson: a skipped empty many-block launch saved ~4.5 us, a
     1-thread one ~0). Candidates per layer: copy_rows_from_mapped (n x K = ~32-40 blocks, nearly all zero-fill GPU
     rows: 400 KB of writes a layer) followed by moe_hit_add (grid 8 x cap); the shared expert's launches; any
     grid sized by cap / max_t_ in verify.cpp post()/pre(). Keep values bitwise: e.g. folding the zero-fill into
     moe_hit_add changes 0 + x only for x = -0.0 (argue it or keep the zero-fill semantics exactly).
  2. **HC is now the furthest from the DRAM: 14.7 ms for ~1.04 GB (~70 GB/s).** hc-read1+router (5.90 + 1.97) is
     the largest HC item; split it (router GEMV + top-k vs the HC read) with one more stamp before choosing a kernel.
     HC down ideas e032/e038/e057/e062 were all neutral; HC up is at 80 registers / 3 blocks (e063).
  3. Experts 22.4 ms (~125 GB/s): gate/up 48 regs / 5 blocks, down 64 / 4 (the (256, 5) cap spills, e049).
     Iteration-12 item 4 (prefetch the next group's grp_ptr / grp_start at GY 8) is still open, ~0.2-0.5 ms.
  4. Dense 19.9 ms (~100 GB/s), head 4.42 (~118 GB/s): IL rows and caps are tuned (e051-e055).
  5. Stalls (decode_min): PLE-type stalls hit e071 req 3 and ~1 in 6 requests tonight; `--ple-row-cache` /
     `--ple-inflight` untested.
  Older list (iteration 12): 1 done (e067), 2 done (e067), 3 done (e071), 4 open (item 3 above), 5 unchanged.
(iteration 14) **Base: commit c65c86ee + overrides/e074-hitcomb.json** (e074/e076, 31.7-31.8). Pair against e076
(the needle run, closer to the mean): 78.44 / 81.18 / 75.47 ms/window, verify 72.29 / 74.75 / 69.71, draft 6.12 /
6.39 / 5.73 (windows 103/100/107); text reference still e015. Done: iteration-13 item 1 for the combine path (e074);
DF_BRANCH (e072), MMVF_ROWS (e073), attention load prefetch (e075): all slower, do not retry. **Next, in order:**
  1. **QSA attention score phase, 3.85 ms/window**: each warp does 12 heads x warp_sum (5 shuffles) per cell. A
     transposed butterfly over the 12 heads (s26_tsum.cuh `tsum<P>`, bitwise per its contract and used by the BF16
     rows kernel) needs 16+8+4+2+1 = 31 shuffles a cell instead of 60. Bitwise only if each head's pairing tree
     equals warp_sum's xor tree: read s26_tsum.cuh first; check texts vs e015 = 1.0. ~0.5-1 ms at best.
  2. **hc-read1+router split** (iteration 13 item 2, still open): one extra stamp between the HC read and the router
     GEMV in a profiled run (e071's table + 1 column) before any router or HC kernel work.
  3. Experts: prefetch the next group's grp_ptr / grp_start at GY 8 (iteration 12 item 4), ~0.2-0.5 ms.
  4. Remaining many-block launches per layer (iteration 13 item 1, minus the combine path now done): the shared
     expert's launches run on their own stream (hidden); look at the per-layer chain in pre() for grids sized by
     max_t_ / cap that mostly exit.
  5. Stalls (decode_min): PLE-type stalls; `--ple-row-cache` / `--ple-inflight` untested.
(iteration 15) **Base: commit 07c4d793 + overrides/e077-attn-pre75.json** (e077/e080, 32.46-32.52). Pair against
e080: 76.38 / 78.98 / 73.57 ms/window, verify 70.50 / 72.83 / 68.05, draft 5.85 / 6.12 / 5.49 (windows
103/100/107); text reference still e015. Done: iteration-14 item 1 (attention score shuffles: e077, via PR #540's
kernel; NC 1/4 slower). **Next, in order:**
  1. **Sweep the tree for other gated bitwise fast paths** (the e077 lesson): grep `cc\[dev\] < 75`, `major == 7`,
     `STRATA_EXPERIMENTAL`, `opt-in until`, `#if defined(__HIPCC__)` kernels with a CUDA-portable body, and
     arch_defaults.cpp tables for sm_8x vs others. One env arm each where the comment claims bit-for-bit; texts vs e015.
  2. **A profiled stage table of the e077 stack** (e077 overrides + STRATA_VERIFY_PROFILE=1), with one extra stamp
     splitting hc-read1 from the router (iteration-13 item 2): what attention + scores costs now (was 4.47), and
     whether the GDN hc0 norm gap (27 vs 8 us a layer) is the previous layer's write being applied.
  3. attn_merge_kernel (33 chunks a head, two passes over part_m): ~0.1 ms/window at most; only with item 2's numbers.
  4. Experts: prefetch the next group's grp_ptr / grp_start at GY 8 (iteration-12 item 4), ~0.2-0.5 ms.
  5. Stalls (decode_min): PLE-type stalls; `--ple-row-cache` / `--ple-inflight` untested.
  Older list (iteration 14): 1 done (e077); 2-5 carried over above.
(iteration 16) **Base unchanged: commit 07c4d793 + overrides/e077-attn-pre75.json**; pair against e080 (above).
Profiled reference: e085's table (iteration-16 log). Done: iteration-15 item 1 (gated sweep: exhausted, e083/e084
neutral), item 2 (profile, without the extra stamp). **Next, in order:**
  1. **Split the expert stage (22.25 ms, the largest) into gate/up vs down before any expert kernel work**: a
     STRATA_BW_PROBE micro-bench timing native_gu_multi_kernel<21> (IQ3_S, 48 regs / 5 blocks) and
     native_down_multi_kernel<20> (IQ4_NL, 64 / 4) on synthetic groups of the real shapes (~30 groups, T 3-4, GY 8),
     reporting GB/s for each. The weaker one is the target. (Or one extra gpu_stamp between the two launches inside
     native_expert_grouped under VERIFY_PROFILE.)
  2. **Expert metadata prefetch** (iteration-12 item 4, still open): at GY 8 a block walks ~3-4 groups, and each
     group starts with dependent loads (grp_ptr -> weights, ent_tok -> activations). Load the next group's
     grp_ptr / grp_start / ent_tok before the current group's dot loop; check registers stay <= 48 (gate/up) /
     64 (down) with 0 B local in the BW-probe print. Bitwise (same values). ~0.2-0.5 ms.
  3. **HC (14.6 ms, furthest from DRAM)**: HC down is grid-limited (41 blocks x 8 warps = ~20 warps a SM), and
     lookahead (e038), smem (e032), caps (e056/e057), and staging (e062-style) are all neutral. HC needs a new idea,
     not another variant of the tried ones; do item 1 first.
  4. Occupancy oddity worth one probe: the rows-1 IL kernel at 56 registers / 9 blocks is ~1.2-1.6 ms slower than at
     61 / 8 (e052, e082). If 9 resident blocks thrash L1, a cap that lands other kernels on fewer blocks could pay.
     Measure before betting a run on it.
  5. Stalls (decode_min): PLE-type stalls; `--ple-row-cache` / `--ple-inflight` untested (none in iteration 16's
     15 requests except a small one in e081).
(iteration 17) **Base: commit 93c74af5 + overrides/e086-exp-pf.json** (e086/e087, 32.67-32.68, the formal best).
Pair against e087: 76.03 / 78.60 / 73.23 ms/window, verify 70.16 / 72.45 / 67.73, draft 5.84 / 6.11 / 5.47 (windows
103/100/107); text reference still e015. Done: expert L2 prefetch (e086, kept), GY 4 with it (e089, neutral), dense
one-wave-ahead prefetch (e088, slower). Next bar for a "better" claim: > 34.38 (32.68 + 1.7), ~-3.6 ms/window.
**Next, in order:**
  1. **Split the expert stage (now ~21.9 ms) into gate/up vs down** (iteration-16 item 1, still open): one extra
     gpu_stamp between the gu and down launches inside native_expert_grouped under VERIFY_PROFILE, or a BW-probe
     micro-bench of the two kernels at real shapes. Pick the weaker one before more expert work.
  2. **Expert first-group cold start**: each block's first group still starts from DRAM (the prefetch is issued
     together with the demand loads). Cross-kernel warm-up (gate/up's last blocks prefetching down's first-wave
     slice, ~0.7 MB) is worth ~1-2 us a layer-window (~0.05 ms/window): low.
  3. Prefetch granularity: one arm with a 128-byte stride (4x fewer prefetch instructions) tells whether
     `prefetch.global.L2` fetches a sector or a line on sm_87; <= 0.1 ms either way.
  4. HC (14.6 ms, ~70 GB/s) still needs a new idea: the per-tile activation staging reads as many bytes from L2 as
     the weights read from DRAM (41 blocks x T x 40 KB); a layout where fewer blocks stage (more rows a block at the
     same warps a SM) is the untested direction, keeping each row's lane order.
  5. Stalls (decode_min): PLE-type stalls; `--ple-row-cache` / `--ple-inflight` untested (none in iteration 17's
     12 requests).
(iteration 18) **Base: commit 93c74af5 + overrides/e090-hnorm-stream.json** (e092, 34.09, leading candidate; the
formal best is still e086/e087). Pair per request in **ms per 256 tokens** (windows x ms/window), not ms/window
alone: drafting arms change the windows. e092: 7832 / 7509 / 7270 ms (105 / 99 / 98 windows, 74.59 / 75.85 / 74.18
ms/window, draft 5.58 / 5.71 / 5.62). Kernel arms (same drafter) still pair by ms/window against e092. Text
reference still e015 (always run `python3 compare.py runs/<exp>/result.json runs/e015-pin14629-grfast/result.json`;
the result.json "gate" is vs the old baselines and reads 0.136 for every correct run). Done: hnorm stream (e090/e092,
kept as settings), min-p 0.4 with it (e093, worse), down kernel 128-thread occupancy (e091, slower).
**Next, in order:**
  1. **Drafter options not yet tried with the stream norm** (one settings run each, texts must stay = e015):
     `STRATA_DRAFT_VOCAB_TOP` 49152 or the full head (40960 was tuned on the pooled drafter; the subset's missing
     mass changes which drafts pass min-p); `--spec-min-p 0.6` (the 0.5-0.6 band's acceptance is unknown for this
     drafter; 0.4 lost). Judge by the summed ms per 256 tokens over the 3 requests.
  2. **A repeat run of e092 without needles** if the next arm is a kernel change: a third e090-config measurement
     settles the median (34.09 vs a stall-hit 32.68) and gives the kernel arm a clean pair.
  3. **Split the expert stage (~21.9 ms) into gate/up vs down** (iteration-16/17 item 1, still open): one extra
     gpu_stamp between the gu and down launches under VERIFY_PROFILE. Expert occupancy caps are exhausted
     (gate/up 48/5 kept; down: (256,5) spills in e049, 56 regs / 9 x 128 slower in e091).
  4. HC (14.6 ms, ~70 GB/s): still needs a new idea (fewer blocks staging the activations, keeping each row's lane
     order); all variants of lookahead / smem / caps / staging were neutral.
  5. Stalls (decode_min): CPU-expert stall in e090 request 2 (`per-layer host 15.05 [CPU 14.80]`); PLE-type stalls;
     `--ple-row-cache` / `--ple-inflight` untested.
  Do not retry: 56-register / 9 x 128-block caps on any kernel (e052, e082, e091), `--spec-min-p 0.4` (e093).
  Operator: if the morning review accepts e092, add `--mtp-hnorm stream` to the base (drafting only; the engine's
  default pooled norm came from tools/mtp_probe.py, not from this Jetson's prompts).
(iteration 19) Done: min-p 0.6 with the stream drafter (e094, worse: min-p is settled at 0.5 for both drafters);
balanced HC down (e095, -0.40 ms/window, bitwise). **Lesson: check the BW-probe occupancy line for every kernel with
a grid near the SM slot count** - gr_down_staged ran 41 blocks at 2 blocks a SM (T3, 84 registers) = 2 waves, and
even at 3 a SM 9 SMs carried 24 rows vs 16. Sizing the grid to the SMs (one 672-thread block each) beat it.
HC up next-wave L2 prefetch (e096, -0.3 ms/window, bitwise). **Next, in order:**
  1. **Retry e088 (dense IL one-wave-ahead L2 prefetch) with the occupancy pinned**: e088's PF build dropped Q6_K
     nc3 r1 from 61 to 56 registers = 9 blocks a SM, a setting that alone costs +1.2-1.6 ms (e052, e082, e091), so
     its +2.2 ms does not show the prefetch itself loses. e096 shows a wave-ahead prefetch pays for
     load-then-compute blocks. Pin 8 blocks (e.g. keep the PF code from freeing registers: check the BW-probe line
     reads 61 / 8 for the pf instance before benching). Dense is ~20 ms at ~100 GB/s: the largest stage left.
  2. **The same next-wave L2 prefetch on other load-then-compute multi-wave kernels**: the BF16 router
     (bf16_f32_mmvf_multi_kernel, 512 one-row blocks, ~1.6 ms/window at ~77 GB/s), the QSA indexer q/k GEMVs, the
     verify head if it runs in waves. One opt-in each; check registers unchanged.
  3. HC up PF distance: 48 = one wave at 3 a SM; try 32 / 96 (env only) once the other arms are in.
  4. HC norm (gr_norm_split_kernel, T x 4 = 12 blocks, ~8 us a launch x 96 = ~0.8 ms/window): keep each thread's
     r*g in registers instead of writing xn and re-reading it after rs (same products, same rounding: bitwise);
     <= 0.2 ms.
  5. Stalls (decode_min): CPU-expert stalls (e090 req 2, e094 req 1: `per-layer host` 6-15 ms); PLE stalls.
(iteration 20) **Base: commit 3f76f45d (= 0613c7a2's decode path) + overrides/e096-hcup-pf48.json** (e096/e098,
34.31-34.40, leading candidate). Pair kernel arms by ms/window against the e096/e098 mean: 74.00 / 75.26 / 73.61
(windows 105 / 99 / 98); text reference still e015. Profiled reference: e100's table (iteration-20 log); profile
any new stack with overrides/e100-profile-split.json. Done: router/indexer next-wave prefetch (e099, neutral).
A repeat of the e096 config >= 34.39 makes it the formal best; one more ~-0.5 ms/window kernel gain does it safely.
**Next, in order:**
  1. **Gate/up kernel (native_gu_multi_kernel<21> sub16, 13.76 ms/window, ~122 GB/s vs down's ~149)**: it runs 48
     registers / 5 blocks of 256 with **48 B local** (the BW-probe line; noted in iteration 10 as "a dead fallback
     path, never runs at n_embd 2560" - verify that claim in the SASS/ptxas output before trusting it: local memory in
     the hot loop would explain the gap). Then compare its structure with native_down_multi_kernel (which stages hq
     in smem, 64 / 4): the gate/up activations come from the q8_1 of x (T x 2.7 KB), read per row group. Ideas that
     keep each row's dot (lane split, order, xor tree): drop the local array (the e035/cda89788 `select` trick for
     s[t]), and a GY / grid split for gate/up alone (STRATA_VRAM_GY is shared by both launches; gate/up's 80 x GY
     grid vs down's 80 x GY).
  2. **route_multi + doorbell (~25 us a layer, ~1 ms/window)**: route_multi is one warp a token in ONE block for
     T <= 8 (one SM busy); a split of the 10 rounds' argmax over more warps that keeps the same comparisons (ties by
     lowest index) is bitwise; the doorbell's seq read-modify-write over the mapped path could be a store of a
     counter kept on the device (the HIP doorbell_publish_value path does exactly that, #649). Stamp them apart first
     (slot 15 is free only if moved out of the sequential 1..24 loop; or reuse slot 32 in a second profile run).
  3. **Dense GEMVs (~20 ms/window, ~100 GB/s)**: still the largest stage. e088's one-wave-ahead L2 prefetch lost
     with an occupancy confound (nc3 r1 fell to 56 registers / 9 blocks); a retry needs the 61 / 8 occupancy pinned.
  4. HC up PF distance 32 / 96 (env only), HC norm in registers: <= 0.2 ms each.
  5. Stalls (decode_min): CPU-expert stalls (e090 req 2, e094 req 1); PLE stalls; none in iteration 20's 9 requests.
  Do not retry: next-wave L2 prefetch in the BF16 mmvf kernel (e099).
  Older list (iteration 11), kept for reference: 1 (GY 4/2) done in e061; 2 (down double buffer) moot after e062
  (the staging costs nothing); 4 (HC up registers) done in e063; 5 (1-column kernels) done in e065.
  Older list (iteration 10), kept for reference:
  a. (done in iteration 11: HC caps spill or do not help; 1-column kernels are at 40 regs / full occupancy)
     **HC kernels and the one-column (draft) kernels: the largest uncapped stages left.** Add gr_down_staged_kernel,
     gr_up_fast_kernel (fused_gr.cu) and the plain native mmvq kernel the Q6_K draft head runs (one column, ~2 ms of
     draft a window) to the BW-probe occupancy print (one report function per TU, as iq_decode_occupancy_report),
     then cap any kernel above ~64 registers one notch (one arm each; reject on any new local bytes).
  b. gate/up at `(256, 6)` (48 -> 40 registers): likely spills (down did at 48); try only if a. is exhausted.
  c. Re-tune IL rows under the new registers: classes 2-3 (qkv/z, Q6_K) at rows 2 with rows-2 kernels now 68-95
     registers; e023/e024 found rows 2 better for qkv/z with the old counts. One env-only arm:
     `STRATA_MMVQ_IL_ROWS="14:2:0,1,2,2,2;14:3:0,1,2,2,2;14:4:0,1,2,2,2"` vs e053.
  d. Dropped: more ALU cuts (Q4_K/Q5_K I2F, IQ3_S apply's one I2F per 8 dp4a): < 0.1 ms each; the gate/up 48 B
     local (dead fallback path, never runs at n_embd 2560).
0. (superseded, iteration 9) **First (one probe, ~6 min): confirm issue-bound directly.** Extend STRATA_BW_PROBE to time the real
   native_mmvq_il_kernel (Q6_K, n_in 2560 x n_out 10240 and n_in 6144 x n_out 2560, synthetic blocks with d = 0) at
   ncols 2/3/4 and native_gu_multi_kernel<21> at n 1..4: if GB/s falls steeply with the column count, the per-column
   ops are the cost; if it is flat at ~100 GB/s, the per-block part (weight decode, address math) is.
   Instruction cuts that keep the math (each: same integers into the same dp4a, same float expression):
   a. IL kernel: split the `m0` loop into a guard-free main part (full groups of 4 blocks) + the guarded remainder,
      and hoist `min(row0 + i, n_out - 1)` and the row pointer out of the block loop (same order of adds).
   b. IQ3_S Split<21>::load: the sign expansion (__vcmpne4 x2 + shifts per grid pair, 4 pairs a chunk) could read a
      256-entry uint2 table of sign masks from shared memory (the values __vcmpne4 makes; __vsub4(g ^ s, s) stays).
      ~16 ALU ops -> 4 LDS a chunk; the grid in smem (e036) was neutral, so check this one with the probe first.
   c. Q6_K: the two `scales[4*i]` int8 loads a block and `d` are per (row, block): fine; the activation scales d8
      (x.scales) are loaded per block per column: could come from one float4 when NC = 4 (interleaved layout).
1. **HC down (gr_down_staged_kernel, fused_gr.cu:672), ~6 ms/window over both reads at ~103 GB/s**: ruled out so
   far: smem reads (e032) and weight latency at one-tile lookahead (e038). Next: a profiled A/B of the block
   geometry (the 41-block imbalance: 9 SMs x 3 blocks vs 7 x 2) and of the per-tile barriers. Rows-per-block
   variants must keep each row's lane order and xor tree. A K split changes the sum order: not allowed.
2. **Dense GEMVs (~21 ms at 83-95 GB/s) and the head (5.3 ms, 97 GB/s)**: wider weight loads. Q6_K's 210-byte
   blocks force 16-bit loads (load_int_b2). Check what STRATA_Q6_PACKED does on the IL path (e006: the packed head
   was slower with the multi kernel) and whether an aligned in-place repack (no duplicate copy: memory floor) lets
   the IL kernel read ql/qh as 4- or 16-byte words. Same integers -> same dp4a -> bitwise.
3. **Experts (~24.6 ms at ~100-120 GB/s)**: the grid gathers are not the limit (e036). Candidates: the IQ3_S
   16-bit loads (get_int_b2 on 110-byte blocks), and prefetching the IQ4_NL down rows before
   native_down_multi_kernel's staging barriers (two __syncthreads per entry chunk).
4. hc0 norm: 27 us a GDN layer vs 8 us a QSA layer (stamp 27 minus layer start: find what else sits in that
   interval), <= 0.7 ms.
3. Stall levers, judged on decode_min over >= 3 runs: `--ple-row-cache 4194304` / `--ple-inflight` (PLE gather:
   e013 and e016's stalls, 200-285 ms/window). NOT `--resident-budget-gib` (e025: pressure_abort at 1.5 GiB).
   Stalls hit 3 of 18 kv-grow requests in iteration 3, none in the 15 requests of iteration 5.
4. (superseded by p037: the floor is ~36 ms/window at 180 GB/s, not ~54 at 120.) Switches cannot reach 45 tok/s;
   kernels near ~150 GB/s could.
5. MTP is tuned: min-p 0.3 is worse (e014), 0.5 stays; spec 3 (e028) and spec 5 (e029) are worse than 4.
   `--lookup-chain` is unlikely to pay on these essay prompts.
6. Do not retry: STRATA_VERIFY_DEVICE_PLAN and STRATA_TSUM (e017: bitwise, +0.3-0.5 ms/window), STRATA_Q6_PACKED
   (head slower, e006), QFUSE (broken without the fix; with it not bitwise and slower), the gfx1151 table, SH_STREAM=0,
   HC_SPLIT=1 (= staged speed), STRATA_GR_DOWN_MAX4 (inert on the staged path), spec-min-p 0.3, auto `--expert-cache`
   in gated arms (slots drift 19057-19092 and move the text), `--spec 5` (e029), IL for 5-6 columns at spec 4
   (e030, never runs), 2-rows-a-warp staged HC down (e032, neutral), IL rows 4 (e035, slower), IQ3_S grid in
   shared memory (e036, -0.3%, noise), 4 rows per 8-lane group in gr_up_fast (HC up is already ~115 GB/s),
   two-tile weight prefetch in the staged HC down (e038, neutral), all 5 gate/up chunk loads hoisted (e039, +5.5%
   slower), gate/up activations staged in smem (e040, +0.6 ms), any "more loads in flight / DRAM pattern / launch
   count" idea (p041/p042: the memory side reaches 146-180 GB/s at these sizes), the no-I2F Q6_K dot on the
   one-column/draft path (e043: draft +0.3 ms/window; kept on the IL path only), GPU clock / power mode (1.29 GHz),
   native_down_multi_kernel `(256, 5)` (e049: spills, +0.6 ms), IL rows-1 at `(128, 9)` / 56 registers (e052:
   +1.2-1.6 ms), IL rows-2 caps (e051 vs e053: neutral), IL rows 1 for every type and class 1-4 (e055: neutral),
   `__launch_bounds__(256, 3)` on gr_up_fast (e056: spills 96 B, +1 ms) or on the staged HC down (e056/e057: T3
   at 3 blocks a SM does not help, T4 spills more), the pre75 attention at 1 or 4 cells a step (e078/e079) or capped
   at `(256, 4)` (spills 16 B: it already runs 64 registers / 4 blocks), aligned 32-bit Q6_K ql/qh loads (e081 with
   a run-time branch: +6 ms; e082 compile-time: +1 ms), STRATA_GDN_SPLIT (e083, neutral), STRATA_DF_PLE (e084,
   neutral), STRATA_EXP_MODE / STRATA_GR_V3 (other sum orders: not lossless-by-construction), one-wave-ahead L2
   prefetch in the dense IL GEMVs (e088: +2.2 ms), STRATA_VRAM_GY=4 with EXP_PF (e089: neutral).
Operator: put `--kv-grow --expert-cache 14629` and env STRATA_GR_FAST=1 (and, from iteration 11, the e059 env:
STRATA_DRAFT_VOCAB_TOP=40960, the Q6_K IL rows string, STRATA_VRAM_GY=8; from iteration 12 STRATA_GR_UP_LR=1 and
STRATA_MMVQ1_WARP=1; from iteration 13 STRATA_NO_PCIE=1; from iteration 14 STRATA_HIT_COMBINE=1; from iteration
15 STRATA_ATTN_PRE75=1; from iteration 17 STRATA_EXP_PF=1; from iteration 19/20 STRATA_HC_DOWN_WPB=21,
STRATA_HC_UP_PF=48 and, if the review accepts the drafting change, `--mtp-hnorm stream`) into
base-overrides.json and re-baseline;
upstream should get the QFUSE fix (iteration 2) and a fast-vs-plain case in fused_gr_check (it compares variants
under the same GR_FAST setting only).

## Harness note (supervisor, 02:25)
- Fixed: `./ar_probe.sh` now puts the engine's own stdout/stderr into `runs/<exp>/probe.txt` (after the supervisor JSON),
  and any file a probe writes under `{RUN}` comes back. p001 predates this; re-run it if you need its --stats.
- Suggestions from the round 1 findings: (1) pin `--expert-cache` to a fixed slot count (e.g. 18000, below the
  18.1K-19.1K the auto size reached) in your overrides so runs are comparable and GPU/CPU ownership stops shifting;
  (2) the 1-in-3 stalls (PLE rows read from the SSD) are a separate lever from the median: try `--ple-row-cache`
  (90 B per row, default 1,048,576 rows), `--ple-inflight`, and the row prefetch path; the fork's earlier `--ple-io`
  screens looked at medians, not stalls. Both are lossless.

## Supervisor note (03:05)
- base-overrides.json stays as it is (warm profile + adaptive tier off) so every row in results.tsv shares one base.
  Build on the current best by copying its overrides file (e.g. overrides/e015-*.json) and adding to it; keep the
  pinned `--expert-cache` in every comparison arm.
