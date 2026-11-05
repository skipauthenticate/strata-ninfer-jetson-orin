# Autoresearch round 3 notes

**FINAL 2 (continuation wrap-up, 2026-11-04 22:05 PST):** installed and verified through `run-iq3_s.sh` as
`fast-r3b`: review **36.74** [34.33-37.08], prose **26.32**, repetition **32.69** tok/s, texts identical to
r3-baseline-f1/f2 on all nine, needles 3/3, prefill 343.7 tok/s, TTFT 11.98 s, min free 11.89 GiB. Settings: r3's
(FINAL below) with `--pool-workers 9` and `STRATA_POOL_SIBLINGS=1`, engine 59692865 (exe 8964f913). Against r3's
install, over every run of each config: review 36.71 vs 36.87 mean (-0.4%, inside the spread), prose 26.56 vs
25.82 (+2.9%), repetition 32.57 vs 30.95 (+5.2%). Rollback: `cp run-iq3_s-fast-r3.sh run-iq3_s.sh`. Details:
"Continuation wrap-up" at the end of this file.

**CONTINUATION (orchestrator, 2026-11-04 14:00 PST): the loop is restarted for 4 hours (until ~18:00 PST) to win
back the 3.5 h it lost at 00:03 to the usage limit. Read this block first; the FINAL block below is the state it
starts from.**
- **Start from the installed best**: `base-overrides.json` (round 2's) + `overrides/r3-e076-best-cost-zcp7.json`
  (`--pool-workers 7`, `STRATA_MISS_ZEROCOPY=1`, `STRATA_SPEC_COST=1` + table). Every new override starts as a copy
  of e076's file plus the change, unless the run tests removing one of those settings.
- **Current best at that setup** (texts identical to f1/f2 on all nine, 19,068 slots), e047 / e076 / e077 / the
  installed start script: review **36.82 / 36.84 / 37.02 / 36.98**, prose **25.92 / 25.67 / 25.90 / 25.72**,
  repetition **30.78 / 30.87 / 31.37 / 31.12**. Rule 4 bar: review above **37.2** (best 37.02 + the 0.2 spread)
  and a repeat confirms. Report prose and repetition the same way (bars ~26.2 and ~31.9).
  **Update C4 (15:20): best identical-text prose = pool 9 SIBLINGS at spec 4 (e082/e086/e087/e089: 26.2-26.8);
  best identical-text repetition = e090 (spec 8 config + pool 9 SIBLINGS: 35.52; e091 35.08), repeat queued (e098).
  Review best unchanged: e077 37.02.** **C12: e098 (e090 + needles) = 34.09 repetition, needles 3/3, texts 1.0: the
  spec 8 config is ~+4% on repetition (median 34.46 over 9 requests vs 31.7-33.7), not +7%.**
- **Gate unchanged**: `gate-baselines.txt` = r3-baseline-f1/f2 (e076/e077 matched them on all nine).
- **Branch rewritten in the wrap-up** and pushed: `ar/decode-speed` = 7 kept opt-in commits + the research record
  (bfc3a758). Commit new work on top as usual. The three never-measured ideas are on the local branch
  `ar/decode-speed-r3-raw`: 2313e235 SPEC_STALE, 96a17911 COPY_MATCH, 7bdb2db8 MTP_PRIORITY (`git -C
  ~/workspace/strata-ar show <hash>`, re-apply by hand). PROMPT_REFILL (7aa743b5) is dropped: text changed.
- **Ids continue at r3-e115 and r3-p016** (e080-e082 C1, e083-e085 + e089 C2, e086-e088 + e090-e094 C3, e095-e099 C4,
  e100-e101 C5, e102-e103 C6; e104-e105 C7 and e106-e107 C8: override files written, NOT queued; e108 C9, queued;
  e109 / e112 / e111 / e113 / e114 C12 ar_run (prio 0, in that order), e110 C12 written, NOT queued; next free id
  r3-e115).
- **C12 17:25: e109 collected = B13 mode 1 CHANGED TEXT, and `pressure_abort` even at 2.5 GiB.** (1) Review texts
  0.28 / 0.52 / 0.23 vs f1/f2 (review finished; aborted at prose request 2). Cause, engine.log:55: `STRATA_MISS_GPU_EXACT=1
  does not cover layer 0 (types 18/20 ...): its PCIe share keeps the GPU kernels`: **some layers' gate/up are IQ3_XXS
  (type 18), not IQ3_S**, so their PCIe share used the GPU's own rounding (the warning prints once, so how many layers
  are IQ3_XXS is unknown). Not a replica defect. **Fix committed: 3fa70777 `PENDING r3-e114`** (expert_source.cpp
  planner: with the switch on, a layer's misses join the PCIe share only if `miss_exact_supported()` covers its types;
  uncovered layers keep CPU misses; also stops check mode adding GPU rows on top of the CPU's on those layers).
  (2) Memory with the PCIe share on: e109's ready line `7011 MiB shared RAM available with everything loaded` vs
  e094's 12,752 (copy 2.5 GiB x 1.46 = 3.65 explains only part: ~2 GiB more with `STRATA_NO_PCIE=0 --pcie-frac 1`,
  cause not found; staging is only kStagingBlobs blobs), then 5.69 by prose request 2. Timing (review): PCIe 0.03 a
  layer-window, CPU experts 0.03-0.05 (review is 99.9% hits); prose request 1: CPU experts 2.03 + PCIe 0.56 a
  layer-window (~22% of the misses reached the GPU), `CPU` 14.78 ms, 23.7 tok/s, decode waited 2.4 s.
  **Consequence: e112, e111, e113 (queued before this, all on 478bbbac, 2.5-3.5 GiB) will change text (e112: check
  mode, its texts show the double-add) and likely abort: read them only for memory numbers and e112's `miss_exact
  check` counts (covered layers only count as compared floats in that build too, so M > 0 would come from IQ3_XXS
  layers' rows: still read the first unequal float's layer).**
  **PENDING r3-e114-gpuexact-covered-resb15** (ar_run prio 0, submitted 17:27, source 3fa70777+0, new build, after
  e111/e113): e109 with the fix and `--resident-budget-gib 1.5` (est. min_avail ~7.1). Gate: texts 1.0 on all nine,
  19,068 slots, no `does not cover` line (the planner now skips those layers silently), timing's `PCIe` > 0 on
  prose/repetition. Texts 1.0 = B13 proven bit-exact on the IQ3_S layers (commit an empty `decode X tok/s (r3-e114
  ...)`; speed is not the point at 1.5 GiB). Texts changed = the replica itself differs: run e112's check mode on
  3fa70777 (copy e112's overrides with `--resident-budget-gib 1.5`, new id) and read the first unequal float.
  Round 4 note: the copy + PCIe share cost ~2.4x the copy in MemAvailable under this harness's 6 GiB floor; B13's
  reach is capped near ~1.5-2 GiB until that is explained (or the floor/headroom changes), and an IQ3_XXS replica
  (ggml_vec_dot_iq3_xxs_q8_K) would widen it to the other layers.
- **C12 (16:50-): e096 collected = `pressure_abort`, min_avail 4.82 GiB, and it says every 4 GiB job queued
  (e097, e099-e103, e108) will likely abort too.** e096's engine read 11.03 GiB available, pinned a 4.77 GiB copy
  (engine.log:33-45), and admission then read 4.82: 6.97 GiB below e094's 11.79, i.e. ~2.2 GiB more than the copy
  (cause unknown; C4 assumed the copy alone). Extrapolated to 4.00 GiB: ~5.6 (fixed extra) to ~5.95 (1.46x the
  copy), both under run_control's 6 GiB floor; qrunner retries an abort once, right away (~12 min an attempt), so
  the 4 GiB jobs may hold the Jetson past 18:00. No cancel without ssh. **Submitted `r3-e109-gpuexact-resb25` with
  ar_run.sh (prio 0: it runs after e097's current attempt, ahead of the retry)** = e100's overrides with
  `--resident-budget-gib 2.5` (est. admission 7.1-8.1 GiB), source 478bbbac+0 (= e101's exe, built by e109). Judge
  it by e100's rules (items 2-6 of the C5 block below): texts 1.0 on all nine + 19,068 slots + PCIe W > 0 = B13
  proven. Speed vs e094 (same settings + timing, no copy) mixes B13 and the copy; the copy-alone twin is written,
  not queued: `overrides/r3-e110-resb25-sibp9.json` (= e097 at 2.5).
  **Confirmed at 16:57: e097 (`--resident-budget-gib 4`) = `pressure_abort`, min_avail 5.96 (both attempts done).
  Rule for every RAM copy: admission MemAvailable drops 1.46x the copy (4.77 -> -6.97, 4.00 -> -5.83 from ~11.79),
  so the largest copy that clears the 6 GiB floor with ~0.3 GiB margin is ~3.75 GiB; 2.5 -> ~8.1, 3.0 -> ~7.4,
  3.5 -> ~6.7.** So e099-e103 and e108 (all 4 GiB) are doomed: ~5 min an attempt, two attempts each. They still
  sit in the queue (no cancel without ssh); prio-0 `ar_run.sh` jobs run ahead of them. e104-e107 (4-5 GiB, never
  queued) need their budgets cut to <= 3.5 before anyone queues them.
  **What e109 can gain at most (e094's timing lines, engine.log:94-133):** repetition windows 111-128 ms = GPU-reach
  47-52 + host 53-63 (`CPU` 40.5-45.2, jobs 11.3-15.7), 4.9-5.4 CPU experts a layer-window (~0.19 ms each on the
  CPU); prose 77-96 ms with `CPU` 15.7-19.4, 2.3-2.7 CPU experts. A moved expert costs the GPU ~2.33 MB at ~36.7
  GB/s (~0.065 ms) + compute, so each one saves ~0.1 ms of the window. Full coverage: repetition ~-25-30 ms a window
  (~+25-30%); at partial coverage scale by `PCIe W / (W + CPU experts)` in e109's timing line (e.g. 40% = ~+10%).
  A gain much below that ratio = the GPU share's own wait (read `GPU-reach wait` vs e094's 47-52).
  Separately, the SSD: e094's `file tier I/O this request` lines (engine.log:93-139) give `decode waited` 2.0-2.7 s
  a repetition request (~30% of a ~7.8 s decode) and 1.0-2.0 s a prose one, while each 4,096-token prompt streams
  ~10.5-11.5 GB from storage through a ~5-6 GB page cache (so after a prompt the cache holds the late layers' blobs,
  LRU). The copy (B14) removes the waits for its experts whatever computes them: compare `decode waited` per request
  in e109/e113 with these, and `page cache held` (the copy's 1.46x shrinks it).
  **PENDING (C12, submitted 16:54-17:00 with background `ar_run.sh`, prio 0, all source 478bbbac+0 = one exe; they
  run in this order after e098, ahead of the doomed 4 GiB jobs; a dead ar_run.sh is collected by `./ar_collect.sh`):**
  1. **e109** (B13 mode 1, 2.5 GiB, timing): gate as above. 2. **e112** (check mode 2, 2.5 GiB, timing): texts must be
  1.0 regardless (the CPU keeps the rows); read the LAST `strata miss_exact check: N floats compared, M unequal`
  and the `first unequal float` line. e109 texts 1.0 + e112 M = 0 over N > 0 = B13 bit-exact (strongest lossless
  evidence for the commit). e109 texts changed: e112's first unequal float decides (1 ulp = a form, see the C5
  block item 5; garbage = an index/bytes slip). 3. **e111** (e109 without timing + `--needles`): rule 4's repeat;
  needles 3/3. 4. **e113** (B13 + mixed-ranked 3.5 GiB copy + spec 8 config, timing): vs e090 (repetition 35.52,
  prose 26.16, review 36.69) / e098; check min_avail > 6 (est. 6.7). **Keep rule:** e109 and e111 texts 1.0, needles
  3/3, prose or repetition above its bar (prose ~26.2 vs e082-class 26.2-26.8 -> needs > ~27.0; repetition at spec 4
  e082-class 31.7-33.7 -> needs > ~34.0) in both = commit an empty `decode X tok/s (r3-e109/e111, prose Y,
  repetition Z): ...` naming e112's counts. If any of e109/e111/e112/e113 is a `build_fail`, build.log has the nvcc
  error: fix once under a new id, re-submit with ar_run.sh.
- **C11 (16:43-): nothing to collect (e096 still running at 16:47); no code, nothing queued. Sized review's fixed
  cost by stage from r3-e038's profile with bytes: big-four dense GEMVs 123 GB/s at T1 (15.77 ms for 1,939 MB),
  expert gate/up 107, shared expert 51 (launch-bound), head 152; at 165 GB/s dense alone = -4.0 ms a window (~+5%
  review), + gate/up ~+10-11%.** Round 4 brief with the bitwise re-layout designs: research-ideas.md B16.
- **C10 (16:34-): nothing to collect (e096 still running at 16:41, 8 pending); no code, nothing queued. Closed B1's
  per-column half under the bitwise rule** (iteration C10 at the end: K-quant integer groups are 4-8 weights, so
  each group's float step is the per-column work whatever computes the integer dot; tensor cores cannot cut it, the
  Q6_K IL path already skips I2F, the draft-head subset is already 40,960). Review's only lever left is B1's fixed
  T1 part (dense ~137 GB/s vs ~180, ~4-5 ms a window; a bitwise weight re-layout, r2 research-ideas.md item 3, L,
  round 4).
- **C9 (16:25-): e095 collected: B13's replica forms are proven, the defaults (1110) are ggml's rounding on every
  piece.** Last `strata replica check` line (engine.log:107; texts 1.0 on all nine, 19,068 slots): q8_K(x) rows
  59,081: fused 59,081 / split 58,872; iq3_s dots 33.6 M: fma 100% / mul+add 48%; expf 16.8 M: fma poly 100% /
  split poly 100%; q8_0(h) rows 122,369: 100%; iq4_nl dots 254 M: fma(X,C,Y*F) 100% / X*C+Y*F 60% / fma(Y,F,X*C)
  53%. So forms = q8k 1 (fused), iq3s 1 (fma), expf 1 (either), iq4nl 0 = `1110`, e100's default: **if e100's texts
  change, the forms are not the cause** (read e101's first unequal float: the GPU replica or the PCIe path differs).
  Review e095: 36.18, prose 16.32, repetition 15.71 (the scalar replicas run beside every miss: speed not judged).
  **Queued speculatively: r3-e108-gpuexact-resb4-needles** (source 478bbbac+0, no new build) = e100's overrides
  without timing + `--needles` = rule 4's repeat of B13, so a B13 win can confirm inside the window. **Judge e108
  only if e100 passed** (texts 1.0 on all nine, PCIe W > 0): e108 needs texts 1.0, needles 3/3, 19,068 slots,
  min_avail_gib > 6; then prose/repetition vs e097 (B14 alone, same settings) and e082-class (pool 9 SIBLINGS: prose
  26.2-26.8, repetition 31.7-33.7); a gain above spread in both e100 and e108 = commit `decode X: ...` (empty
  commit, the code is in b6f4b116/478bbbac). If e100's texts changed: ignore e108.
  Also pre-reviewed (C9) the two never-compiled commits every e099+ build includes: 74590f2b (rank profile,
  generate.cpp) and 9343e5b7 (IQ4_NL NEON, off in every run): no compile defect found (scopes, types, NEON
  intrinsic signatures, guards all checked). And re-reviewed miss_exact.cu step by step against the now-proven CPU
  replicas: no defect (iteration C9 at the end of this file lists what was checked).
- **C8 (16:18-): nothing to collect (e095 still running at 16:22); review has no lever above the spread left this
  round (B1b ~0 by r2's per-T profile, N6/B2 ~0.5%: iteration C8 has the arithmetic).** Written, NOT queued, for the
  case B13 fails but the RAM copy (B14) gains: `r3-e106-resb4-cost8` (e090 + `--resident-budget-gib 4`) and
  `r3-e107-resb4-mixrank-cost8` (+ mixed-ranked copy); queue the one whose spec 4 twin (e097 / e099) won. Details and
  the judge rule: iteration C8 at the end of this file.
- **C7 (16:08-16:25): nothing finished to collect (e095 still running at 16:15; the queue is slower than ~6 min a
  run, likely another project's GPU lock), no new code, no commit.** Two settings-only B13 follow-ups are written
  for source 478bbbac (= e101's exe; HEAD is still 478bbbac, so queuing them builds nothing new). **Queue them only
  if e100 passes (texts 1.0 on all nine, 19,068 slots, PCIe W > 0):**
  1. `./ar_queue.sh r3-e104-gpuexact-direct "e100 + --pcie-mode direct" overrides/r3-e104-gpuexact-direct.json`:
     the replica reads the RAM copy in place (no staging copy kernel: the blob's 2.33 MB is read once, not three
     times). Texts must equal e100's (same arithmetic, same bytes). Judge vs e100 on prose/repetition medians and
     the timing line's GPU-reach wait; if direct is slower, the 1-byte loads from host-mapped pages are the cause
     (fix designed in research-ideas.md B13 "C7": shared-memory row staging, `STRATA_MISS_GPU_STAGE=1`).
  2. `./ar_queue.sh r3-e105-gpuexact-resb5 "e100 + --resident-budget-gib 5" overrides/r3-e105-gpuexact-resb5.json`:
     a bigger RAM copy = more misses reach the GPU. Only if e100's min_avail_gib (results.tsv) is >= ~7.3 (the copy
     takes 1 GiB more; run_control.py kills the server below 6). If e102 (mixed ranking) beat e100, add
     `"STRATA_RESIDENT_RANK_PROFILE": "/home/<user>/strata/Strata-data/profiles/iq3_s-mixed-r3.bin"` to it first.
  Before both: a passing B13 best needs its clean repeat + `--needles` (rule 4); that comes first if time is short.
- **PENDING from C6 (queued 16:04, behind e101; source 478bbbac+0 = e101's exe, no new build: exe_sha256 must equal
  e101's):** **r3-e102-gpuexact-mixrank** = e100's overrides + `STRATA_RESIDENT_RANK_PROFILE=.../iq3_s-mixed-r3.bin`
  (the RAM copy, and so the GPU share's reach, ranked by held-out code/prose/repetition routing; the GPU cache keeps
  the warm profile). **r3-e103-gpuexact-mixrank-cost8** = e102 on e090's spec 8 config (`--spec 8`, IL56, IL_SPLIT,
  8-row SPEC_COST table; T <= 8 and 80 entries fit miss_exact's limits). Both have timing on. **Judge only if e100
  passed** (texts 1.0, PCIe W > 0); if e100's texts changed, e102/e103 change too: ignore them. Gate texts 1.0 on all
  nine, 19,068 slots. e102 vs e100 (and e099 vs e097 for B14 alone): prose/repetition medians and the timing line's
  PCIe W (more misses on the GPU = the ranking widens B13's reach). e103 vs e090/e098 (repetition 35.52/?): the
  stack. Engine.log: `STRATA_RESIDENT_RANK_PROFILE: the RAM copy ranked by ...` and the B13 startup line. A win
  (repetition or prose above its bar with texts 1.0): repeat without timing + `--needles`, commit `decode X: ...`.
- **PENDING from iteration C5 (queued 15:46 PST, behind e094-e099): r3-e100-gpuexact-resb4, source b6f4b116+0
  (commit b6f4b116 "PENDING r3-e100..e102": opt-in `STRATA_MISS_GPU_EXACT=1`, B13 step 1; new file
  src/kernels/cuda/miss_exact.cu + verify.cpp call site + CMakeLists entry; new exe).** = e097's settings
  (pool 9 SIBLINGS, `--resident-budget-gib 4`, timing) + `STRATA_NO_PCIE=0` + `--pcie-frac 1` +
  `STRATA_MISS_GPU_EXACT=1` (forms default `1110`). What it does: every CPU miss whose blob is in the page-locked RAM
  copy (up to 16 a layer) goes to the verify window's existing "PCIe share", and that share runs replica kernels of
  ggml-cpu's aarch64 path instead of the GPU's own (q8_1, dp4a) kernels, so the rows should be the CPU's bits.
  **How to judge:**
  1. `build.log`: a compile error in miss_exact.cu or verify.cpp = `no_result`. Fix it once under a new id (the file
     was never compiled; nvcc is not on the Mac); twice: revert (rule 8).
  2. engine.log startup: `STRATA_MISS_GPU_EXACT=1: the PCIe share of the misses runs ggml-cpu's rounding on the GPU
     (forms ...; exp table [1] 3fefd9b0d3158574 [31] ...)`: [1] must be glibc's tab[1] `0x3fefd9b0d3158574`. Also
     `resident RAM mode: 4.00 GiB of experts in RAM (page-locked)`; no line `does not cover layer`.
  3. Reach: engine.log `strata decode timing:` lines end with `CPU experts X (Y entries), VRAM hits Z, PCIe W` per
     layer-window: W > 0 = the GPU share ran (W = 0 everywhere: the copy is not registered/mapped, see
     expert_source.cpp pinned()/device_alias(), or the copy holds none of the misses). Compare `CPU experts` and the
     host `[jobs / CPU]` ms with e097's.
  4. **Gate: texts 1.0 on all nine and slots 19,068 = B13 proven** (the GPU computed misses with the CPU's bits).
     Then judge speed vs e097 (same settings, CPU computes those misses): prose/repetition medians and the timing
     line's `CPU` ms; review should be within ~1% (3 extra early-exit launches + a staging copy a layer). A win: commit
     `decode X: ...` (opt-in), repeat without timing + `--needles`, then stack on e090's spec 8 config.
  5. **Texts changed** (agreement < 1.0): read e095's `strata replica check` line (it counts which CPU-side form is
     bit-equal to ggml for each piece). Re-queue the same source with `"STRATA_MISS_GPU_FORMS": "<q8k><iq3s><expf><iq4nl>"`
     set to e095's 100% forms (q8k: 1 fused / 0 split; iq3s: 1 fma (proven by e092/e093); expf: 1 fma cubic / 0 split;
     iq4nl: 0 fma(X,C,Y*F) / 1 X*C+Y*F / 2 fma(Y,F,X*C)). Same source = no rebuild. If e095 already matches 1110 and
     texts still change, the GPU replica differs from the CPU replica somewhere: next step is a self-check (GPU rows
     vs the CPU's for the same experts, counted per piece), not a forms guess.
  6. GPU reset / `pressure_abort`: the copy (4 GiB) + PCIe staging are the only new memory; report it.
- **PENDING from C5 (queued 15:52, after e100): r3-e101-gpuexact-check, source 478bbbac+0** (commit 478bbbac = b6f4b116
  + check mode; a second new exe, so a second build) = e100's overrides with `STRATA_MISS_GPU_EXACT=2`: the misses
  in the RAM copy stay CPU entries (rows and texts are e097's), the replica computes the same experts beside them
  into a side buffer, and a compare kernel counts unequal floats. **Gate: texts 1.0** (anything else = a planner bug
  in check mode: expert_source.cpp `mx_check`). **Read engine.log:** `strata miss_exact check: N floats compared, M
  unequal` (printed about every 2^20 floats; take the last line) and, if M > 0, `first unequal float: layer L entry E
  row R gpu XXXXXXXX cpu YYYYYYYY`. M = 0 over millions of floats = the replica is bit-exact (e100's texts should
  then be 1.0 too; if they are not, suspect the PCIe path, not the arithmetic). M > 0: compare the two hex values
  (a 1-ulp difference on some rows = a float-step form: try e095's forms via `STRATA_MISS_GPU_FORMS` in a new check
  run, same source = no rebuild; most rows wrong / large differences = a decode or indexing slip in miss_exact.cu).
  N = 0 (no lines): the share never ran (see e100 item 3).
- **e094 collected (C5, 15:53): B12 gate/up NEON kernel CLOSED, no gain.** e094 (= e092/e093 with the switch off,
  same exe 2f3a369d, timing on): texts 1.0 on all nine; review 30.47 (6.82/../36.61: request 1 stalled, `stage
  302.63` ms a window = the PLE/SSD stall, not the switch), prose **26.92**, repetition **32.94** vs e092 (mode 1):
  36.25 / 26.45 / 30.75. Repetition `CPU` ms a window: e094 45.2 / 40.5 / 45.0 (jobs 11.3-15.7) vs e092 47.0 / 53.6 /
  57.5; prose 12.4 / 19.4 / 15.7 vs 13.8-19.7. Decoding each IQ3_S block once for 1.6-1.7 tokens an expert does not
  beat ggml's per-token dot on the A78AE (the rows are memory-bound). So 9343e5b7 (IQ4_NL down, cheaper decode) is not
  worth queuing either. Repetition window (e094): ~111-128 ms = GPU-reach wait 47-52 + host 53-63 (jobs 11-16, CPU
  40-45): the host part is what B13 (e100) attacks. The timing line's `PCIe X.XX` (per layer-window) field shows the
  GPU share directly: read it in e100.
- **e093 collected (C5, 15:45): `STRATA_IQ3S_NEON_MT=2` (multiply, then add) CHANGES prose text (agreement 0.3268;
  review and repetition 1.0)**, so the texts gate does discriminate one float step and **ggml-cpu is built with FMA
  contraction (mode 1 is ggml's rounding)**. review 36.47, prose 25.85, repetition 31.06 (timing on). This is also
  the evidence behind miss_exact.cu's default forms (ggml's C compiled gnu11 contracts `a*b + c`).
- **r3-e099-resbudget4-mixrank-sibp9** (C4, queued 15:18, **source 74590f2b** = bec4857c + opt-in
  `STRATA_RESIDENT_RANK_PROFILE`, generate.cpp only; new exe) = e097 + the RAM copy ranked by
  `iq3_s-mixed-r3.bin` (held-out code/prose/repetition routing, no benchmark text) while the GPU cache keeps the warm
  profile. Check engine.log `STRATA_RESIDENT_RANK_PROFILE: the RAM copy ranked by ...`. Texts must be 1.0 and slots
  19,068. Judge vs e097 (same budget, review ranking) and e094: if e099 beats e097 on prose/repetition, the ranking
  is the lever (commit message `decode X: ...`, opt-in); a build failure in build.log: fix once under a new id.
- **e092 collected (C4, 15:26): `STRATA_IQ3S_NEON_MT=1` (fma) keeps texts 1.0 on all nine** (exe 2f3a369d, 19,068
  slots, startup line present): GCC does contract ggml's `sumf += d*(sumi1 + sumi2)` into an FMA, so **mode 1 is
  ggml's rounding** (e093, mode 2, should change text; e095's iq3_s fma count should equal its total). Speeds with
  timing on: review 36.25, prose 26.45, repetition 30.75. Repetition timing per request: 61/55/53 windows, avg T
  4.26-5.00, 124-170 ms a window, `CPU` 47.0 / 53.6 / 57.5 ms, `jobs` 11.0-21.7, 5.5-5.6 CPU experts (9.7-10.5
  entries) a layer-window; prose `CPU` 13.8-19.7 ms. **The keep decision waits for e094** (same settings + timing,
  switch off): compare these `CPU` ms and the prose/repetition medians.
- **e088 judged (C4, 15:16):** `STRATA_MMVQ_IL_ROWS` rows 2 at 5-6 columns for Q6_K/IQ4_XS/Q4_K/Q5_K on e078's
  spec 8 config + timing: texts 1.0, review 36.12 (timing on), prose 25.11, repetition 32.84 (34.7/../32.84) vs
  e078/e079 32.35/33.19: **no gain, closed.** Review never picks T5/T6 under SPEC_COST (T1-T4 + 0-2 T8 a request),
  so the 5-6 column rows only reach repetition, where the windows are miss-bound.
- **r3-e098-cost8-sibp9-needles** (C4, queued 15:21, bec4857c, after e097) = e090's overrides again + `--needles`:
  rule 4's repeat of the repetition best. Confirms if texts 1.0, needles 3/3 and repetition >= ~34.5 (e090 35.52,
  e091 35.08). Then commit an empty `decode 36.69 tok/s (r3-e090/e098, repetition X, not a review best): ...` and
  give the owner e090's overrides as the repetition-heavy setting (review -1%, prose ~0).
- **PENDING from iteration C4 (queued 15:10-15:15 PST, behind e088 and e092-e094; source bec4857c = 9135446b + the
  diagnostic below; e095-e097 must share one exe_sha256, new vs 9135446b's):**
  1. **r3-e095-replica-check** = e082's settings + `STRATA_MISS_REPLICA_CHECK=1` (commit bec4857c, read-only
     diagnostic, speed not judged). Gate: texts 1.0 on all nine (it only reads; anything else = a bug in the hooks).
     Read engine.log: the startup line `STRATA_MISS_REPLICA_CHECK=1: counting bit-equal replicas`, then the LAST
     `strata replica check (bit-equal of total):` line. Each piece has a total and a bit-equal count per form; a form
     that equals its total is how the CPU rounds that step. Pieces: q8_K(x) rows (fused / split magic-bias add),
     iq3_s dots (fma / mul+add: must agree with whichever of e092/e093 kept texts), expf (glibc algorithm, fma /
     split polynomial), q8_0(h) rows (one form), iq4_nl dots (3 forms). If every piece has a form at 100%, the
     B13 idea (research-ideas.md: misses computed by the GPU with the CPU's exact rounding, texts identical) is
     feasible; if a piece has no 100% form, read that replica against its source (comments name the file) and fix
     it before any GPU work. Either way: no commit needed beyond bec4857c (already committed as PENDING); record the
     counts here and in research-ideas.md B13.
  2. **r3-e096-resident-sibp9** = e082 + `--resident-experts` + timing. **Expected to end `pressure_abort`** (queued
     before I read bench.sh: run_control.py kills the server below 6 GiB MemAvailable, and `--resident-experts` pins
     the non-GPU experts down to 4 GiB of headroom); qrunner requeues it once. If it does run (`resident RAM mode:
     X GiB` in engine.log), judge it as e097.
  3. **r3-e097-resbudget4-sibp9** = e082 + `--resident-budget-gib 4` + timing: the 4 GiB of non-GPU experts the
     (review) profile ranks hottest are page-locked in RAM, so CPU misses on them never wait for the SSD; same bytes,
     same CPU kernels, so **texts should be 1.0** (a change = the resident copy is not the file's bytes: report it).
     Check engine.log `strata generate: resident RAM mode: 4.00 GiB of experts in RAM (page-locked)`, min_avail_gib
     (must stay > 6), cache_slots 19,068 (the copy is built after the GPU cache). **Judge vs e094** (same settings +
     timing, no RAM copy): prose/repetition medians, per-request `decode waited X ms in N fetches` (e090 had review
     0.3-0.7 s, prose 1.7-2.0 s, repetition 2.2-2.7 s of ~10 s / ~7 s decodes), host `[jobs / CPU]` ms in the timing
     line, and TTFT (the prompt path reads non-GPU experts too). Review should not move (99.9% hits). If prose or
     repetition beats e094 by more than spread with texts 1.0: queue a clean repeat (no timing) + `--needles`, then
     try 5 GiB (min_avail permitting: keep >= ~7 GiB) and the stack with e090's spec 8 config. If the gain is small,
     the profile's ranking is the limit (it ranks by review routing): a prose/repetition-aware ranking is e099.
     **Risk to read the result by:** MemAvailable (~12 GiB) includes the page cache that already serves part of the
     misses (`page cache held 5.8 GB at the read` a request; each 4,096-token prompt streams all ~11 GiB of non-GPU
     experts through it). A 4 GiB pinned copy shrinks that cache by 4 GiB, so the net can be ~0 or negative for the
     experts outside the copy; compare `page cache held` and `decode waited` per request with e094's.
- **C4 judged e090/e091 (15:09): spec 8 config + pool 9 SIBLINGS is the best identical-text repetition.** e090
  (= e078's IL_SPLIT + `--spec 8` + SPEC_COST to 8 rows + zc, with pool 9 SIBLINGS; exe bf6750eb, texts 1.0 on all
  nine, 19,068 slots): review **36.69** (35.00/36.78/36.69), prose **26.16** (28.23/25.14/26.16), repetition
  **35.52** (34.25/35.52/36.12: every request above e082's 32.81-33.34 and e078/e079's 32.35/33.19). e091 (= e090 +
  `STRATA_COPY_MATCH=12`): review 36.79, prose 25.94, repetition 35.08 (34.35/36.51/35.08); copy mode fired on
  repetition only (32-33 windows a request, all but 0-1 took the copy) and gained nothing at spec 8 either: **COPY_MATCH
  is closed.** Not a review best (36.69-36.79 < 37.2); repetition +7% over pool 9 at spec 4 (e082/e086/e087 median
  33.6), +14% over e076/e077. Owner note: for a repetition-heavy deployment, e090's overrides are the best
  identical-text setting measured (needs a repeat + needles before recommending).
- **PENDING from iteration C3 (queued 14:40-14:48 PST; collect with `./ar_collect.sh`; 7 jobs, ~45 min + one build):**
  1. Settings on d4d760c5 (exe must equal bf6750eb), in queue order: **e087** `--pool-tasks 128` on e082's settings
     (compare with e086 / e082 / e089); **e090** e078's spec 8 config + pool 9 SIBLINGS (compare with e078/e079:
     36.58/36.80, 24.75/23.80, 32.35/33.19); **e091** = e090 + `STRATA_COPY_MATCH=12` (compare with e090: COPY_MATCH
     should pay here, the chain is up to 7 steps); **e088** e078 + `STRATA_MMVQ_IL_ROWS` 2 rows at 5-6 columns +
     timing (compare T5/T6 verify ms in `by window size` and repetition with e078/e079). Gate: texts 1.0 on all nine.
  2. **Kernel on 9135446b (new exe; the three must share one exe_sha256, different from bf6750eb): opt-in
     `STRATA_IQ3S_NEON_MT=1|2`** = a NEON gate/up kernel that decodes each IQ3_S block once for an expert's 2-8
     window tokens (ggml's vec_dot, which the Orin's miss pool runs today, decodes it again per token). All three
     runs = e082's settings (pool 9 SIBLINGS) + `STRATA_DECODE_TIMING=1`: **e092** mode 1 (fused multiply-add
     accumulate), **e093** mode 2 (multiply, then add), **e094** switch off (the A/B baseline for both). Check
     engine.log for `STRATA_IQ3S_NEON_MT=N: IQ3_S gate/up rows decode each block once` (e092/e093). **Gate: exactly
     one of e092/e093 should give texts 1.0 on all nine** (the one whose accumulate matches how GCC compiled ggml's
     `sumf += d*(sumi1 + sumi2)`; my guess is mode 1). If both change text, the kernel has a decode slip (read the
     sign / scale / q8 offsets against ggml-cpu/arch/arm/quants.c:3929-4037) or ggml's build differs (e.g. no
     dotprod: integer sums are still exact, so it would be the float step); revert the call site, keep notes. A
     build failure (`no_result`, compile error in build.log): fix once and re-queue under new ids; twice: revert.
     **Judge the passing mode** vs e094 (same exe, same settings): per-request `CPU` ms in the decode-timing line
     (repetition ~27-37 ms a window today) and prose/repetition medians; expected repetition +4-7%, prose +2-4%,
     review ~0 (99.9% hits). Keep (commit `decode X: ...`, opt-in) if texts 1.0 and repetition or prose beats e094
     by more than spread; then a repeat + `--needles`. Then the same for IQ4_NL down rows (cheaper decode, smaller
     gain) is the follow-up.
- **e089 judged (C3, 14:50): pool 9 SIBLINGS does NOT confirm as a repetition best; it is a trade-off.** e089 (=
  e082 + needles, exe bf6750eb): texts 1.0 on all nine, needles 3/3, 19,068 slots; review **36.02** (33.37/36.36/
  36.02), prose **26.74** (28.37/26.08/26.74), repetition **31.65** (below the 32.5 confirm bar). e086 (pool-tasks
  64 on the same settings): review 36.47 (34.53/36.47/36.49), prose 26.81, repetition 33.63, texts 1.0. Across
  e082/e089/e086 vs e076/e077: review 37.02/36.02/36.47 vs 36.84/37.02 (~-1%), prose 26.19/26.74/26.81 vs
  25.67/25.90 (~+3%), repetition 33.26/31.65/33.63 vs 30.87/31.37 (~+5%). Not committed as a best; no owner
  recommendation (review is the headline). e086's 64 tasks: no clear change vs e082 (one run).
  **e087 (`--pool-tasks 128`, 14:55): review 36.87 (34.51/../36.94), prose 26.69, repetition 33.74, texts 1.0.**
  `--pool-tasks` 64/128 do nothing measurable (the default 3 x threads is fine). Pool 9 SIBLINGS over four runs
  (e082/e089/e086/e087): review 37.02/36.02/36.47/36.87 (median ~36.7 vs pool 7's 36.82-37.02), prose 26.2-26.8
  (vs 25.7-25.9), repetition 33.26/31.65/33.63/33.74 (vs 30.8-31.4). A real prose/repetition gain (+3% / +7%)
  at a ~-0.5% review cost; it stays the base of the C3 kernel runs because those are A/B'd against e094.
- (done, queued by C3) **Written by C2:** e086 / e087 `--pool-tasks 64 / 128` on e082's settings; e088 IL rows 2 at
  5-6 columns on e078's; e090 e078's spec 8 config + pool 9 SIBLINGS; e091 = e090 + `STRATA_COPY_MATCH=12`.
- **NEW CANDIDATE (C2, 14:17): r3-e082 = e076 + `STRATA_POOL_SIBLINGS=1` + `--pool-workers 9`** (workers pinned to
  CPUs 1-9, host on 0): texts 1.0 on all nine, 19,068 slots, exe 24cd29e7. Review **37.02** (34.51/37.21/37.02: ties
  e077, below the 37.2 bar), prose **26.19** (28.86/22.54/26.19), **repetition 33.26 (33.34/33.26/32.81: every
  request above e076's 30.86-30.95; bar 31.9)**. Pinned 7 (e080: 36.10/22.55/28.47) and pinned 11 (e081:
  35.00/20.75/24.78) both lost, so 9 is the setting (11 leaves no free core; 7 is unexplained, one run).
  (done, judged in C3 above: not confirmed) **r3-e089-sib-p9-needles** (= e082 again + `--needles`, source 8ae45a4a with its new switches off; exe
  must equal e083's): if repetition repeats >= ~32.5 with texts 1.0 and needles 3/3, the repetition best is e082's
  setting: commit an empty `decode 37.02 tok/s (r3-e082/e089, repetition 33.26, not a review best): ...` naming
  the evidence, and recommend `"--pool-workers": "9"` + env `"STRATA_POOL_SIBLINGS": "1"` to the owner. Then make
  e082's settings the base of every new override (e086/e087 already are).
- **e083-e085 judged (C2, 14:37): 8ae45a4a compiled (exe bf6750eb); texts 1.0 on all nine; no gain from any of the
  three switches** (SPEC_STALE 36.73 / 23.17 / 30.66, COPY_MATCH 36.93 / 25.75 / 31.32, MTP_PRIORITY 36.98 / 25.85 /
  30.68). Recorded in the empty commit d4d760c5 (HEAD). All stay opt-in. COPY_MATCH's real test is the spec 8
  config (chain up to 7 steps): written, not queued, `r3-e090-cost8-sibp9` (e078 + pool 9 SIBLINGS) and
  `r3-e091-copy12-cost8-sibp9` (e090 + COPY_MATCH=12). Details in iteration C2.
- (done) **iteration C2's PENDING: r3-e083 / e084 / e085 = items 2+3, one build at 8ae45a4a** (= 9e32f657 +
  SPEC_STALE + COPY_MATCH + MTP_PRIORITY re-applied by hand; never compiled anywhere before). Each = e076's
  overrides + one switch: e083 `STRATA_SPEC_STALE=32`, e084 `STRATA_COPY_MATCH=12`, e085 `STRATA_MTP_PRIORITY=2`.
  exe_sha256 must differ from e080's and be one value for all three. A `no_result` with a compile error in build.log:
  fix it (the code is in 8ae45a4a), re-queue under new ids. Check engine.log for each switch's startup line
  (`STRATA_SPEC_STALE=32:`, `STRATA_COPY_MATCH=12:` + the per-request `copy mode: N windows ...`, `STRATA_MTP_PRIORITY=2:`).
  Gate: texts 1.0 vs f1/f2 on all nine. Judge: review vs the 37.2 bar; repetition vs e076/e077 30.87/31.37 (STALE and
  COPY target repetition; PRIORITY targets review). A winner gets a repeat (+ `--needles`) and then a combination with
  the best pool setting from e080-e082; switches with no gain stay opt-in, committed as "not a new best".
- **e080-e082 collected by C2 (texts 1.0 on all three): pool 7 / 11 / 9 pinned = review 36.10 / 35.00 / 37.02,
  prose 22.55 / 20.75 / 26.19, repetition 28.47 / 24.78 / 33.26. Pool 9 is the candidate (see NEW CANDIDATE).**
- (done) **iteration C1's PENDING: r3-e080 / e081 / e082 = item 1, `STRATA_POOL_SIBLINGS=1` at pool 7 / 11 / 9**
  (commit 9e32f657 on ar/decode-speed; queued as source bfc3a758+1, same tree; one exe_sha256 for all three, new vs
  e076's 69995077). Check engine.log first: `N pool workers on logical processors 1,2,...,N` (not `1,2,3`). Gate:
  texts 1.0 vs f1/f2 on all nine (each row is computed whole by one thread; pool 3 -> 7 kept texts, so any pool
  count should too). Judge: prose/repetition vs e076/e077 (25.67-25.92 / 30.87-31.37); review vs the 37.2 bar. The
  best variant gets a repeat (+ `--needles`) next; if all three are within spread of e076, the switch stays opt-in
  with a "no gain" commit message and the loop moves to item 2.
- **The board is shared**: another project's jobs take `~/gpu.lock` for up to 20 minutes each, so a queued
  bench may wait. Waiting does not change its numbers.
- **Ranked items (C5 refresh, 15:56):** (1) collect e095-e101 (top PENDING blocks); (2) B13: e100 texts + speed,
  e101 exactness count; if both pass, a repeat without timing + `--needles`, then the RAM copy ranked for
  prose/repetition (e099's `STRATA_RESIDENT_RANK_PROFILE`) and a 5 GiB budget, then e090's spec 8 config on top;
  (3) B14 alone (e097/e099) as the fallback if B13 fails; (4) B12 is closed (e094); (5) review: B1b / N6 only if
  time is left (multi-iteration).
- **Ranked items (C4 refresh, 15:22; the C1 list below is done: 1 = SIBLINGS, 2-3 = no gain, 4 = still open):**
  1. Collect and judge the queue (top PENDING blocks): e092-e094 NEON gate/up kernel, e095 replica check, e096/e097
     /e099 RAM copy of the non-GPU experts (B14), e098 repetition-best repeat.
  2. Prose/repetition, texts identical: B14 (RAM copy; budget <= ~5 GiB under the 6 GiB floor) and its ranking;
     B12 gate/up NEON kernel; then B12 down (IQ4_NL) only if the CPU part still dominates.
  3. Prose/repetition, larger: B13 (GPU computes misses with the CPU's exact rounding) if e095 finds a 100% form
     for every piece. Multi-iteration.
  4. Review headline: B1b (5th column, <= ~1.5%) or N6 (commit fold, ~0.5-1%), both multi-iteration kernel items.
- **Ranked items (C1, kept for the record):**
  1. **The miss pool runs on 3 of the 12 cores (measured, sysfs read by the orchestrator at 13:58 PST).** On the
     Orin every CPU reports `physical_package_id` 0 and `core_id` 0-3 inside each of 3 clusters (`cluster_id` 0/1/2),
     and `thread_siblings_list` is each CPU alone (no SMT). `src/kernels/cpu/pool.cpp:246-262` keys physical cores on
     `(physical_package_id, core_id)`, so it marks cpu4-cpu11 as SMT siblings: 4 "cores", the host thread on 0, the
     pool on 1-3 at any `--pool-workers` (every log of the round: `N pool workers on logical processors 1,2,3`).
     Fix as an opt-in switch (for example key on `thread_siblings_list` or add `cluster_id`), then measure pool 7 and
     11 on all 12 cores. Expect the gain on prose and repetition (CPU miss compute); texts should stay identical if
     each row's kernel and reduction order do not depend on which thread runs it (check that before queuing).
  2. **SPEC_STALE** (raw 2313e235) and **COPY_MATCH** (raw 96a17911) on top of e076's settings: window choice only.
  3. **MTP_PRIORITY** (raw 7bdb2db8): stream priority only.
  4. The fused multi-column kernels for the 5th and 7th column cliffs (PLAN.md): review's remaining lever, bigger.
- Fact from another project on the board (measured on this board, 14:00 PST): with 4 independent 16-byte loads in flight per
  thread, the GPU streams ~180 GB/s from cudaHostRegister'ed or cudaHostAlloc-mapped memory, the same as device
  memory (one load per thread: ~155). So the GPU could compute misses straight from host pages, but that moves
  misses from CPU to GPU rounding: texts change, REVIEW class. Not a keep under this round's rule.
- **`ar_collect.sh` now runs one at a time (orchestrator, 16:30 PST)**: two collects at once logged r3-e095 twice
  (16:24:46 and :49); the second row is deleted. A second collect now waits for the first (`lockf`, up to 15 min).
- **r3-e094's review median 30.47 is a stall, not the switch (orchestrator, 16:00 PST).** Review request 1 ran 256
  tokens in 37.5 s (6.8 tok/s): its 41 T4 windows averaged 815 ms (`stage` 302 ms per layer-window); requests 2-3
  ran 36.6 / 30.5. No other job overlapped: another project's job held the GPU lock until 15:44 (the bench waited from
  15:31), e094 measured 15:44-15:52 alone. Judge e094 on prose/repetition and per-request numbers, not review.

**FINAL (wrap-up, 2026-11-04 02:30 PST):** installed and verified through `run-iq3_s.sh`: review **36.98**, prose
**25.72**, repetition **31.12** tok/s (baselines f1/f2: 35.47-35.61 / 18.4-18.6 / 16.4-16.6), texts identical on all
nine, needles 3/3. Settings: round 2's + `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1` + `STRATA_SPEC_COST=1` +
`STRATA_SPEC_COST_TABLE=52.5,63.5,74.5,86.7`, engine 8f6ecdcd. Details: "Wrap-up" at the end of this file.

Current best (base, PASS): the installed round 2 best (r2-e043 settings, engine 8d466b5d, warm profile learned on
review), `base-overrides.json`. Per workload (r3-baseline-w1/w2, texts identical across both, 19,068 cache slots):
review **35.17 / 35.08**, prose **17.38 / 17.43**, repetition **15.52 / 14.24** (pr_mean ~16.5); cache hits 99.9 /
84.5-89.8 / 77-79%. 32K needles 3/3 (r3-baseline-needles, same settings).
**OWNER CHANGE (21:12 PST): ~5 GiB more free memory, but the expert cache did NOT grow (orchestrator, 21:40).**
The owner stopped two idle services on the board (a training worker, a small llama-server). r3-baseline-f1 / f2 (21:21 /
21:32, cbe51765 switches off, exe d5177e48): **19,068 slots / 36.27 GiB, the same as w1/w2, and texts 1.0 vs w1/w2
and vs each other on all nine**; min free memory 11.92 / 12.04 GiB (w1/w2 7.06-7.08). Per workload, f1 / f2:
review **35.47 / 35.61** (34.33/36.24/35.47, 34.55/36.46/35.61), prose **18.43 / 18.58**, repetition **16.58 /
16.44** (pr_mean 17.5); hits 99.9 / 87.0 / 78.7-78.9%. Review runs ~1% above w1/w2 with the services stopped, so
**rule 4's bar is now f2's 35.61 + spread** (e036's 35.46 does not clear it). Texts and slots are unchanged, so
runs before 21:12 still gate correctly; compare their *speed* with w1/w2 and later runs' speed with f1/f2. The
freed ~5 GiB is unused headroom: a cache above 19,068 slots is a placement experiment (texts change through
CPU-vs-GPU rounding of misses: REVIEW class).
**Why the cache did not grow (iteration 9, code read): `--expert-cache 14629` in base-overrides.json is the cap**,
not free memory. An explicit N grants N x the largest blob (2.539 MiB: 36.27 GiB) and the slots are then filled in
profile order with each layer's own smaller blob: 14,629 -> 19,068 slots (generate.cpp:4933-4956; free memory binds
only below that budget + the 700 MiB reserve). Queued as A8: `--expert-cache 16400` / `15500` (e048-e054, item 4).
Gate baselines: **`gate-baselines.txt` = r3-baseline-f1, r3-baseline-f2 (switched 21:40 PST; same texts as w1/w2).**
**QUEUE CAP (owner, 22:05 PST): `ar_queue.sh` refuses a job while 12 or more are pending (exit 4, "queue full").**
At 22:04, 22 were pending (~2.5 h of Jetson time) while iterations last 10-20 min. When it refuses: judge what is
queued, keep coding, commit as PENDING, and queue in a later iteration. Prefer fewer, decisive runs over variants.
Best prose/repetition seen (REVIEW class, texts differ from the warm gate, not a base): **r3-e039 `--adapt-every 16`
+ env `STRATA_ADAPT_LAG=2`** (625b9ae0, exe 46732e1c, 19,068 slots, no GPU errors/aborts): review **34.96**
(33.89/34.96/36.15), prose **28.73** (23.15/28.73/29.54), repetition **40.44** (28.2/40.4/43.1), pr_mean **34.59**
vs ~16.5. Lag 2 removes e014's review dip (e014 at lag 1: review 32.23 with a 24.0 request). Texts vs f1/f2: review
0.675/0.132/0.041, prose 0.0185, rep 1.0. Its stack with zc + pool7 is e060 (+ needles), queued. See iteration 10.
r3-e040 (lag 1 + trace + timing) ran the same speeds (34.70 / 27.93 / 40.44) with no review dip: e014's 24.0
request was a stall, so lag 1 vs lag 2 does not decide speed (texts differ between them: placement timing).
**Best PASS-class prose/repetition (needs its repeat, r3-e044): `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1`** =
r3-e036 (625b9ae0, exe 46732e1c, 19,068 slots, started before 21:12): texts 1.0 on all nine; review **35.46**
(33.97/35.46/35.65), prose **24.31** (27.19/24.16/24.31), repetition **29.93** (29.93/30.96/29.62), pr_mean
**27.12** vs ~16.5 (+64%; rep x1.93). Zero-copy is opt-in in commit 3ea866a2 (switch only, no code change needed).
Review 35.46 clears the 35.27 bar by one run; **mechanism found in iteration 8 (r3-e037 vs e001, same windows):
zero-copy cuts review's windows by 1.3-2.2 ms (`jobs` 2.0-3.2 -> 0.4-0.7 ms: review's misses are mostly
page-cached, not SSD-cold)**, so expect review ~+2%. Rule 4 still needs e044. If e044 confirms (texts 1.0 vs f1/f2, needles 3/3), recommend `"--pool-workers": "7"` + env
`"STRATA_MISS_ZEROCOPY": "1"` for the owner's base and commit `decode X: ...` (empty commit naming the evidence).
**Confirmed PASS-class (settings only): `--pool-workers 7`** = r3-e010 (timing on) and its
repeat r3-e033 (625b9ae0, exe 46732e1c, clean): texts 1.0 on all nine, 19,068 slots; review 35.11 / **35.05**
(34.04/35.65/35.05), prose 19.29 / **21.01**, repetition 18.83 / **18.57** (pr_mean ~19.8 vs ~16.5). Review is
unchanged (not a headline gain, rule 4); prose +21%, repetition +25% with identical texts. **Recommended for the
owner's `base-overrides.json`: add `"--pool-workers": "7"`** (agents cannot edit that file). Until the owner does,
every agent override that measures prose/repetition should name it explicitly.
**HARNESS WARNING (iteration 6, 20:40 PST): a queued job rebuilds only the files whose Mac mtime is newer than the
Jetson's last build of them.** qrunner.sh copies each snapshot with `rsync -a`, which keeps the Mac mtimes, and
ninja rebuilds by mtime. So a snapshot taken *before* another state's build never recompiles its changed files.
**r3-p010..p013 and r3-e019..e032 are all invalid**: one stale binary (exe a80b089d, partly af6a5faa) segfaulted
(rc -11) at the first decode window. The engine started 3 times in each bench, `no_result`, `supervisor: fail`.
The rules for agents until the owner fixes it:
1. Keep one source state in the queue. Queue a new state only after the previous state's first job has *finished
   building* (its bench or probe has started).
2. Check `exe_sha256` in results.tsv against the source state before believing a run.
3. After a revert, edit a file: a fresh mtime forces the rebuild (`touch` and `find -exec` are blocked for agents).
Owner fix: in qrunner.sh, copy with `rsync -rlpD --checksum --delete` (no `-t`): changed files then get the
current time and unchanged files keep theirs.
**Owner: fixed at 20:57 PST** (qrunner.sh now copies exactly that way; the fixed runner takes over after r3-e034).
Jobs from r3-e035 on rebuild correctly; rules 1-3 above can relax to rule 2 (check `exe_sha256`).
PENDING (collect with `./ar_collect.sh`): five source states queued, in queue order (items 2-6), plus three built
but not queued (items 7-9, iterations 12-14; all go on HEAD 7bdb2db8 as one build):
1. (done) 625b9ae0's last run e040 was collected at 22:00. **e041 collected 22:28 (iteration 14): PASS, texts 1.0
   on all nine, exe d5177e48 = f1/f2's binary, `GDN commit batched (36 layers), QSA commit batched`; review 35.02
   (34.09/35.69/35.02), every request 0.3-0.8 below f1/f2's; prose 16.23, rep 15.19. No gain: e042/e043 decide.**
2. **cbe51765 (queued by iteration 7 at 20:54 by `date`; its files are newer than 625b9ae0's build, so e041 rebuilds
   verify.cpp + verify_kernels.cu + native_qsa_indexer.cu and dependents)**: r3-e041-cb, r3-e042-cb-diag,
   r3-e043-cb-off, then **r3-e044-zc-pool7-needles** (repeat of e036 + `--needles`; the commit-batch switch off).
   Judge with the table in "iteration 7"; gate all four against f1/f2. e041's exe_sha256 must differ from 46732e1c; e042-e044
   must equal e041's. Expect e041 to start ~21:45 (plus its build) and e043 to end ~22:20. With the owner's runner
   fix a third source state may be queued at any time (check its exe_sha256).
3. **af839e5b (HEAD, queued by iteration 8 at 21:25, behind e044): r3-e045-scost, r3-e046-scost-diag,
   r3-e047-scost-zcp7** (opt-in `STRATA_SPEC_COST=1`, the cost-aware MTP window). e045's exe_sha256 must differ
   from e041's (it rebuilds draft_policy.cpp, mtp.cpp, generate.cpp and everything including mtp.hpp); e046/e047
   must equal e045's. Judge with the table in "iteration 8". Expect them ~22:30-22:55.
4. **af839e5b again (same source state as item 3, no rebuild; queued by iteration 9 at 21:33, behind e047):
   settings only, every switch of af839e5b off.** r3-e048-c16400-zcp7, r3-e049-c16400-zcp7-rep,
   r3-e050-c15500-zcp7, r3-e051-c16400-zcp7-diag, r3-e052-mix-c16400-zcp7, r3-e053-zcp7-adapt16,
   r3-e054-c16400-zcp7-adapt16. exe_sha256 must equal e045's. All but e053 change the slot count on purpose, so
   the gate will say slots drift / texts differ vs f1/f2: that is expected, judge them with the table in
   "iteration 9" (self-agreement e048 vs e049, not the f1/f2 gate). Expect them ~23:00-23:50.
5. **7aa743b5 (HEAD, queued by iteration 10 at ~21:50, behind e054): B8 `STRATA_PROMPT_REFILL=1`.** r3-e055-prefill-
   zcp7, r3-e056-prefill-zcp7-rep, r3-e057-prefill-zcp7-diag, r3-e058-prefill-zcp7-adapt16, r3-e059-prefill-zcp7-
   a16lag2, r3-e060-zcp7-a16lag2-needles (switch off). e055's exe_sha256 must differ from e045's (prefill.hpp changed:
   prefill.cpp, generate.cpp and everything including prefill.hpp rebuild); e056-e060 must equal e055's. REVIEW class
   (placement): judge with the table in "iteration 10". Expect them ~23:50-00:35.
6. **23a09959 (HEAD, queued by iteration 11 at 22:03, behind e060): B1c `STRATA_IL_SPLIT=1`** (7-8 column windows run
   the dense GEMVs and the head as two interleaved passes). r3-e061-ilsplit-spec8, r3-e062-ilsplit-cost8-zcp7,
   r3-e063-ilsplit-cost8-a16lag2. e061's exe_sha256 must differ from e055's (verify.cpp changed); e062/e063 must equal
   e061's. Check engine.log for `STRATA_IL_SPLIT=1: windows of 7-8 columns` first (a no_result with a compile error
   in build.log = fix 23a09959, never compiled on the Mac, and re-queue under new ids). Judge with the table in
   "iteration 11". Expect them ~01:00-01:30.
7. **2313e235 (HEAD, NOT QUEUED: the queue was at 22 pending all of iteration 12): B7b `STRATA_SPEC_STALE=32`.**
   Override files are written: queue, once `ar_queue.sh` accepts (fewer than 12 pending), in this order:
   `./ar_queue.sh r3-e065-stale32-zcp7 "B7b: SPEC_STALE=32 + IL56 + zc + pool7" overrides/r3-e065-stale32-zcp7.json`,
   then r3-e066-stale32-il56-a16lag2 and r3-e067-stale32-cost8-a16lag2 (same pattern). If only one slot is free,
   queue e067 first (it decides). It rebuilds draft_policy.cpp + generate.cpp + the test: e065's exe_sha256 must
   differ from e061's; e066/e067 must equal e065's. **r3-e064 stays reserved for e060's repeat.** Judge with the
   table in "iteration 12". Also: **read e063's repetition requests 2-3 with this bug in mind** (iteration 12).
   **Update (iteration 13): HEAD is now 96a17911 (2313e235 + B5 copy mode, opt-in), so e065-e067 queued later build
   96a17911. Its switch is off in their overrides, so they still measure B7b alone.**
8. **96a17911 (HEAD, NOT QUEUED: still 22 pending at 22:23): B5 copy mode `STRATA_COPY_MATCH=12`.** Override files
   are written. Queue them on the same source state as item 7 (one build for all six), in this order once the cap
   allows: e069 (decides speed), e068 (PASS gate), e067, e066, e065, e070, then e071 (optional). If only 2 slots
   are free: e069 + e066 (the pair). Judge with the table in "iteration 13". If e065-e070's build fails (neither
   2313e235 nor 96a17911 was compiled on the Mac), read build.log: a copy-mode error = fix 96a17911's 34 lines (or
   `git revert` it and re-queue e065-e067 alone); a SPEC_STALE error = fix 2313e235's draft_policy code.
9. **7bdb2db8 (HEAD, iteration 14, NOT QUEUED: 21 pending at 22:38): `STRATA_MTP_PRIORITY=2`** (the drafter's
   streams at the highest priority beside the async commit graph; mtp.cpp only). Same build as items 7-8: queue
   everything on HEAD as one source state. Override files written: r3-e072-prio-diag (= e037's overrides + the
   switch: same windows, compare per request), r3-e074-prio-zcp7 (= e044's settings + the switch, PASS gate),
   r3-e073-prio-cb-diag (e072 + `STRATA_COMMIT_BATCH=1`). **Suggested order for HEAD's batch once the cap allows:
   e072, e069, e068, e074, e066, e067, e065, e073, e070, e071** (e072 and e069 decide the two new switches; drop
   the tail if the cap binds). Judge with the table in "iteration 14". exe_sha256: one new value for all of them.
**Compile check (iteration 14, four read-only reviewers): af839e5b, 7aa743b5, 23a09959, 2313e235 and 96a17911 have
no definite compile errors and no default-path change** (every identifier in scope, signatures match, offsets in
il_split_mm right). Caveats, switch on only: SPEC_STALE without SPEC_COST reprices a width by one unclamped round
(a stall round can price it high until the next retry); PROMPT_REFILL counts carry over a request that takes no
new loan; IL_SPLIT at n = 5 without IL56 runs a 1-column second pass (not in any queued run).

## Profile finding (orchestrator, 17:20 PST): cache misses decide prose and repetition
- `iq3_s-mixed-r3.bin` = the warm profile interleaved one-for-one with held-out routing traces (real code from the
  Strata repo, Austen and Dickens from Project Gutenberg: 2 code review, 2 prose, 2 repetition; none of it benchmark
  text; `~/strata/ar/merge_profile.py`). As an override: `{"args": {"--expert-profile":
  "/home/<user>/strata/Strata-data/profiles/iq3_s-mixed-r3.bin"}}`. Measured as r3-base-1..3 (texts identical
  across the three, 19,112 slots, needles 3/3): review **31.49** (hits 99.7%), prose **22.6** (92.3%), repetition
  **29.7** (92.3%); pr_mean ~26.2 vs ~16.5.
- So each 0.1% of hit rate is worth ~3% of decode (a miss is a ~1.3 ms SSD read on the critical path; a T4 window
  makes ~1,400 expert lookups): review loses 10% for -0.2% hits. The cache holds ~78% of the 24,576 experts, so no
  fixed profile serves every kind of text. **The prose/repetition lever is per-conversation placement**: the
  adaptive tier (off in the base since round 1, `--adapt-every 100000`, for an old iGPU-reset report under memory
  pressure) and prompt-informed warming (the prompt's own prefill routing predicts what a summary or a copy will
  route to; for repetition almost exactly). Kernel work moves review; placement moves prose and repetition.
- Next for Phase A (add to PLAN.md's table): A6 the adaptive tier with `--adapt-every` 16 / 64 / 256 on all three
  workloads (watch for GPU resets and `pressure_abort`; texts may change only through cache-size or tier effects:
  treat a text change with matching cache slots as REVIEW, not FAIL, and explain it); A7 the mixed profile (done
  above); then a B8 code item: after prefill, swap in the experts the prompt routed most (placement only).

## Starting point (orchestrator, 2026-11-03 ~16:45 PST)
- Harness: every Jetson build and measurement goes through the Jetson's queue runner (`ar_queue.sh` returns at once;
  `ar_run.sh` / `ar_probe.sh` wait; `ar_collect.sh` logs finished runs). Each bench = review + prose + repetition in
  one server session (~6 min). bench.sh waits for free memory to settle before starting the server (back-to-back
  runs otherwise got 18,633 instead of 19,068 cache slots, and different text: r3-baseline-2).
- **Expert-cache profile (done 17:20: see the profile finding above):** the warm profile was learned on the review prompts, so
  prose (84-90% hits) and repetition (77-79%) read experts from the SSD: repetition accepts every draft yet runs at
  ~15 tok/s. A profile from held-out routing traces (real code from the Strata repo, Project Gutenberg prose: two
  each of code review, prose, repetition; none of it is benchmark text) is being built; when it lands, the base and
  the gate baselines change and this block says so. Until then, do not draw conclusions from prose/repetition speed.
- Plan: `PLAN.md`, corrected by `research/plan-review.md` (read both). Summary of the corrections: A2 must not use
  `--mtp-max-t 8` (uncaps the MTP chain; use `--lookup-chain 4/7` alone); B1 is dense IL + shared only (HC belongs to
  B2) and is split into steps (rows-table measurement, a CP-4 5-column kernel, then 7-8 columns), <= +10%; B2 is a
  2-phase HC fusion prototype judged in a served profile, +2-4%; from B3 keep `STRATA_GU_SWIGLU`, `SIDE_MIXER`
  (check exclusivity with our draft branch) and `STRATA_COMMIT_BATCH`; B4 = EXPDEC or gate/up rows per wave, +2-4%
  together; Phase A adds a `--spec 8` + `STRATA_IL56=1` + `STRATA_SPEC_DEPTH=1` measurement and `STRATA_VERIFY_PROFILE`
  on all three workloads; the base already runs `--spec-min-p 0.5`, so test 0.7 and 0.85 as new values (<= +2%).

## Log (newest last)

### iteration 1 (2026-11-03 17:20-), r3-e001..e008: Phase A settings batch (queued, results pending)
- Every override names `--expert-profile` explicitly: r3-base-1..3 ran with `{}` overrides yet got the mixed profile
  (args.txt), so the Jetson's base was switched for them; do not assume which profile `{}` gets. Warm runs pass
  `.../iq3_s-warm.bin`, mixed runs `.../iq3_s-mixed-r3.bin`.
- **A6 (adaptive tier) not run: program.md rule 2 (hard) says "Keep the adaptive tier off", which the 17:20 profile
  finding's A6 contradicts.** The owner must lift rule 2 in program.md before an agent runs `--adapt-every` 16/64/256.
  Prompt-informed warming (B8, placement only, adaptive tier still off) is allowed under rule 1 and is the
  prose/repetition lever that stays inside the rules.
- Queued, in this order (~6 min each; e001-e004 warm profile, gated against w1/w2):
  | exp | change | decides |
  | --- | --- | --- |
  | r3-e001-diag | timing + spec depth (measurement) | comparator for e004 and e008; window histogram per workload; per-depth acceptance on prose/repetition |
  | r3-e002-minp085 | `--spec-min-p 0.85` | keep only if review > 35.17 + spread (~0.1) with texts identical, then repeat |
  | r3-e003-minp07 | `--spec-min-p 0.7` | same rule as e002 |
  | r3-e004-spec8 | `--spec 8` + `STRATA_IL56=1` + timing + depth | per-depth acceptance at depths 4-7 on review: if the 7-draft chain gives < ~3.3 tokens a window, wide windows never pay on review and B1's value there is the per-column slope only (plan-review item 11). Texts must stay identical (exact verify); slots may drift (more graphs) |
  | r3-e005-mixdiag | mixed profile + timing + depth | comparator for e006/e007; texts vs r3-base-1..3 |
  | r3-e006-mixlc4 | mixed + `--lookup-chain 4` (spec -> 8, MTP still 4) | repetition speed and T5-T8 windows vs e005. Plan-review item 4: the policy prices T8 at ~162 ms for 8 tokens vs T4 71.5 for 4, so expect T4-T6 even at 100% acceptance; if so the limit is the 5th-column kernels (B1), not lookup settings |
  | r3-e007-mixlc7 | mixed + `--lookup-chain 7` | more chained drafts than e006 only where the MTP stops early |
  | r3-e008-vprof | `STRATA_VERIFY_PROFILE` + timing | per-stage table on all three workloads (speed not comparable: the profiler slows windows and the policy re-prices) |
- Not queued, low value: `--suffix-draft 12` (repetition already accepts 100%), min-p 0.85 + `--spec 6` (round 2
  closed spec 5/6: 25 ms fifth column; queue only if e002 wins).
- **r3-e001-diag: PASS (texts 1.0 on all nine, 19,068 slots), review 34.96 (33.82/35.43/34.96), prose 17.43, rep
  15.29** (timing costs ~0.5%). Per request, from `strata decode timing` / `by window size` / `spec depth`:
  | workload | windows | avg T | tok/window | ms/window | GPU-reach wait | per-layer host [jobs / CPU] | draft |
  | --- | --- | --- | --- | --- | --- | --- | --- |
  | review | 95-100 | 3.03-3.09 | 2.56-2.69 | 75.5-76.1 | 61.0-61.7 | 2.7-4.2 [2.0-3.2 / 0.35-0.60] | 5.9-6.1 |
  | prose | 113-125 | 2.53-2.73 | 2.05-2.27 | 116-132 | 43.0-46.4 | 59-79 [25-29 / 31-48] | 5.4-5.8 |
  | repetition | 63-65 | 4.08-4.19 | 3.94-4.06 | 258-284 | 50.5-52.5 | 193-219 [91-105 / 101-112] | 6.9-7.2 |
  - Review by T (verify ms): T1 47.5-48.2, T2 56.9-58.5, T3 67.8-69.6, T4 79.3-80.9 (51-52 T4 windows a request at
    2.43-2.63 accepted). Depth acceptance d0/d1/d2: 72/79 48/63 33/41, 75/81 47/58 41/44, 74/84 49/60 36/42. Same cost
    model as round 2.
  - Prose: d0/d1/d2 acceptance lower (80-89 / 70-76 / 72-76%), fewer T4 windows (27-34); 1.9-2.8 CPU-miss experts a
    layer-window.
  - Repetition: suffix drafts 56-58 windows a request, every draft accepted (186/186, 192/192, 188/188); T6 windows
    16-21 a request at 5.00 accepted, verify 376-402 ms; 4.9-5.5 CPU-miss experts a layer-window (8.5-9.4 entries).
  - **Finding: on prose and repetition the window is the CPU-miss path, not the GPU.** Repetition: 193-219 of 258-284
    ms is per-layer host, split about evenly between `jobs` (the blob fetch, 91-105 ms) and `CPU` (the miss experts'
    compute, 101-112 ms); the GPU part is ~51 ms + 7 ms draft. Prose: 59-79 of 116-132 ms. Round 2 found the pool runs
    on 4 of the 12 cores (pool.cpp:250 dedups Orin's cores on `(package, core_id)`; e028 `--pool-workers 7` halved
    `CPU` on review, which was too small to matter there: 0.35 ms). Here `CPU` is ~40% of the repetition window.
  - Both halves are threads/scheduling with the same CPU kernels and the same misses (fixed profile and slots), so
    texts stay identical: PASS-capable, unlike any placement change (research-ideas.md B8/B9).
- **r3-e002-minp085: texts identical (1.0 all nine), review 31.04 (31.04/32.74/30.88) = -11.7%; prose 17.97 (vs
  17.38/17.43), rep 14.86. Killed.** The 0.85 gate cuts drafts that review accepts (depth acceptance 79-90%), so
  windows shrink faster than their cost. Prose +3% on one run is inside its spread (16.2-19.6 per request in w1).
- **r3-e004-spec8 (`--spec 8` + `STRATA_IL56=1` + timing + depth): texts identical (1.0 all nine, 19,068 slots),
  review 30.92 (30.91/30.92/32.54) = -12%; prose 18.2/15.3/16.1, rep 14.3/15.0/14.9. Killed as a setting; it was a
  measurement.** Review per request: 81-86 windows, avg T 3.93-4.21, 2.98-3.16 tokens/window (spec 4: 2.56-2.69) but
  96-102 ms/window (75.5-76) and draft 8.2-8.7 ms (5.9-6.1). Verify ms by T on review: T4 78-81, **T5 102** (+22: the
  5th-column cliff), T6 114-126, **T7 145-149** (+30: a second cliff), T8 154-157. T8 windows (14-18 a request)
  accept 4.12 / 4.22 / 5.29 drafts: **depths 4-7 do accept on review** (spec depth d3 18/19, 20/25, 17/22; d4 10/12,
  13/14, 10/12), so plan-review item 11's "< 3.3 tokens" kill does not fire. At today's prices a T8 window gives
  0.033-0.040 tok/ms vs T4's 0.038-0.046: wide windows lose only because of the T5 and T7 cliffs. If B1 brings T5-T8
  to the T2-T4 slope (~11.5 ms/col: T8 ~129 ms), T8 at ~5.3 tokens = 0.041 tok/ms, about T4: B1's review value is
  the per-column slope, not wider windows. Repetition at T8: 6.5-7.0 accepted in 462-487 ms, per-layer host 262-293
  ms (CPU-miss path): no gain there until B9.
- **r3-e003-minp07: texts identical (1.0 all nine, 19,068 slots), review 33.73 (33.57/34.25/33.73) = -4.0%; prose
  18.36, rep 15.35 (both inside spread). Killed.** min-p is closed: 0.5 (base) > 0.7 > 0.85, monotone. Do not retry.

### iteration 2 (2026-11-03 ~17:50-), r3-e009..e016: B9 thread settings + A6 adaptive tier (queued, pending)
- program.md now allows A6 (rule 2: "testing it is allowed ... `--adapt-every` 16 / 64 / 256: it changes placement
  only"), so iteration 1's block on A6 is lifted. The overrides e009-e013 were written by iteration 1 but never
  queued (not in the queue at 17:50); queued now unchanged, with the three A6 runs between them.
- Order in a bench (bench.sh:41-42): review (warmup + 3), then prose, then repetition, one server session. So with the
  adaptive tier on, review runs from the warm profile plus what its own requests teach; prose and repetition inherit
  the review-adapted cache and each has a warmup request to adapt on before its three measured requests.
- Adaptive tier mechanics (generate.cpp:849-852, 879, 8175-8210): every `--adapt-every` windows a round swaps up to
  `--adapt-swaps` (96) of the most-routed non-resident experts in for the least-routed resident ones (a candidate needs
  usage >= 2 and >= the victim's + 1.5; counts decay x0.7 a round). Blocking tier (`--adapt-async 0`, default).
  The iGPU reset warning (generate.cpp:4638-4648) is HIP/AMD only; the Orin is CUDA.
  | exp | change (all warm profile) | decides |
  | --- | --- | --- |
  | r3-e009-pool11 | `--pool-workers 11` + timing | vs e001 (same timing): `CPU` part of the prose/repetition window (e001: 101-112 ms rep, 31-48 prose). Texts must be 1.0 on all nine (rows whole per task, r2 e028) |
  | r3-e014-adapt16 | `--adapt-every 16` | prose/rep tok/s vs w1/w2 (17.4 / 15.5) and vs the mixed profile (22.6 / 29.7); review must stay >= ~34.9. Texts may change (placement): REVIEW, not FAIL, if slots match. Watch engine.log for GPU errors, `pressure_abort`, adapt ms/round |
  | r3-e012-pool11-clean | `--pool-workers 11`, no timing | speed vs w1/w2 on all three; texts 1.0. Keep (PASS, prose/rep gain) only if prose or rep beats its baseline range (prose 16.2-19.6 per request; rep 14.1-15.7) on the median and review does not drop below 34.9 |
  | r3-e015-adapt64 | `--adapt-every 64` | as e014 |
  | r3-e011-pool11-io16 | `--pool-workers 11` + `STRATA_IO_PF_THREADS 16` + timing | vs e009: does `jobs` (rep 91-105 ms) drop with more reads in flight |
  | r3-e016-adapt256 | `--adapt-every 256` | as e014 (review has ~100 windows a request, so 256 = ~1 round per 2.5 requests) |
  | r3-e013-iostage | `STRATA_IO_PF_STAGE=1` + timing | vs e001: staged copies vs page faults on the miss path; texts must be 1.0 |
  | r3-e010-pool7 | `--pool-workers 7` + timing | vs e009: whether 11 workers oversubscribe the 12 cores (8 I/O threads + host) |
- **r3-e013-iostage is a no-op** (found after queueing): the base reads the GGUF in place (`--mmap-experts`, engine.log
  line 16), so `io_fill_` is already false and `STRATA_IO_PF_STAGE` changes nothing. Read e013 as a repeat of e001
  (timing spread on all three workloads), not as a staging test. Details: research-ideas.md B9 "Correction".
- How to judge A6: it is a placement change, so texts on prose/repetition (and maybe review) will differ from the warm
  gate. It is a candidate for the base only if (a) no GPU errors / aborts, (b) review median >= 34.9 (inside the
  baseline spread; the headline must not pay for the other two), (c) pr_mean clearly above 16.5. If it wins, the next
  step is a repeat + `--needles` and an owner-visible REVIEW entry (new gate baselines needed, as for the mixed
  profile). If review drops (swap stalls), try `--adapt-async 1` (not bit-exact run to run: generate.cpp:854-856) or
  `--adapt-swaps` 32 next.
- Code read this iteration (no source change, engine tree clean at 53b3a758): the CPU-miss path on prose/repetition
  is serial per layer: assemble every missed blob (8 threads spawned per layer, pread or memcpy of 3 GGUF slices),
  then compute. Repetition: ~700 MB assembled a window, ~215 MB of it from the SSD. Overlapping the uncached reads
  with the compute of the cached blobs is bitwise-safe (per-expert batches are already split by `kMaxSplitMulti`)
  and worth ~-70 ms of a ~260 ms repetition window. Full brief: research-ideas.md, B9 step 2.
- **Ranked next steps (iteration 3+):**
  1. Collect e005-e016 (`./ar_collect.sh`), judge each by the tables above (iteration 1 and 2). Queue empties ~19:15 PST.
  2. Code: B9 step 2 `STRATA_MISS_OVERLAP=1` (research-ideas.md). One build + up to 3 variants: overlap alone; overlap
     + the best `--pool-workers` from e009/e010/e012; overlap + timing. Gate: texts 1.0 on all nine; keep if rep or
     prose beats its baseline range and review holds.
  3. If A6 wins on pr_mean without costing review: repeat + needles, REVIEW entry, propose new gate baselines.
  4. Code: B3a `STRATA_GU_SWIGLU` (review, ~+1%, research-ideas.md B3a).

### iteration 3 (2026-11-03 ~18:00-19:00 PST): B9 code (overlap queued, zero-copy committed), e005/e006 collected
- **r3-e005-mixdiag (mixed profile + timing + depth): texts 1.0 on all nine vs r3-base-1/2 (by hand), 19,112 slots;
  review 31.47, prose 22.58, rep 29.62** (= r3-base-1..3; timing costs ~0). Repetition per request: 70 windows, 3.66
  tokens/window, 122-128 ms/window = GPU-reach 47-48 + per-layer host 63-67 [jobs 28-33, CPU 33-35]; 2.0 CPU experts
  a layer-window. Prose: 116-121 windows, 96-99 ms, host 39-43 [jobs 13-19, CPU 23-26]. Review: host 5.9-6.7 [jobs
  4.2-5.1, CPU 1.1-1.3] at 0.08-0.10 CPU experts a layer-window.
- **r3-e006-mixlc4 (mixed + `--lookup-chain 4`): texts 1.0 vs r3-base-1/2; review 31.11, prose 22.87, rep 29.81 (=
  e005). Killed as a setting; measurement kept.** Repetition now runs T8: 28-30 T8 windows a request at 7.00 accepted
  (verify 240-247 ms), 6.6-6.9 tokens/window at 219-232 ms/window vs e005's T4 at 3.66 per 122-128 ms: 0.031 vs
  0.030 tok/ms, a wash. The T8 window is GPU-reach 81-83 + per-layer host 118-129 [jobs 52-62, CPU 63-64]: the
  CPU-miss path still holds 55% of it. So wider repetition windows pay only once the miss path and the column price
  drop (B9 below, then B1).
- **Correction to the B9 brief (research-ideas.md B9): decode misses are page-cache hits, not SSD reads.** The
  per-request I/O line includes the prefill: review requests (0.1 CPU experts a layer-window, ~1 GB of decode blobs)
  read 11-13 GB from storage, so a 4,096-token prefill re-reads ~12-13 GB of non-resident experts from the SSD.
  Repetition reads 13.9 GB from storage for 47.4 GB of expert reads, so its decode reads ~1 GB from storage and ~30
  GB from the page cache. `jobs` (92-105 ms a repetition window on the warm profile) is therefore mostly the memcpy
  that assembles ~5.5 blobs a layer from their three GGUF slices into stage buffers (plus 8 thread spawns a layer),
  not SSD waits. Consequences: (a) the overlap queued below only hides the few cold reads: expect a small gain;
  (b) zero-copy (compute from the mapping's slices, no assembly) is the real `jobs` lever.
- Code 1, **`STRATA_MISS_OVERLAP=1` (commit af6a5faa, queued as e017-e019)**: per layer, misses whose pages are not
  in RAM (new `ExpertSource::pages_cached`, the sampled mincore) are read by `prefetch` on a background thread while
  the pool computes the cached ones (pass 0), then built and computed (pass 1). Jobs keep their numbering (pass 1
  appends to `jobs_multi`), every entry writes its own `out` row, rows are whole per task (pool.cpp drain modes 5/6),
  so texts must stay 1.0. The wait for the cold reads is counted under `jobs`, not `CPU`, in the timing line.
- Code 2, **`STRATA_MISS_ZEROCOPY=1` (commit 3ea866a2, HEAD, not queued: one build per iteration)**: aarch64 only,
  native packs, the GGUF in place. A miss whose pages are in RAM (`pages_cached`) and that `ExpertSource::slice`
  can place (not the RAM copy, not an exchange) becomes a job with `blob` = its gate slice and new
  `ExpertJobMulti::up` / `down` = its up / down slices in the mapping; it skips `prefetch` and `blob()`. The kernels
  take the pointers as trailing defaulted args (`native_gu_rows(..., up)`, `native_down_rows(..., down)`); on ARM
  those are the per-row loops that already compute `blob + up_off + r * gu_row`, so it is the same bytes through the
  same code. Layout check: `per[0] = per[1] = n_ff * gu_row = up_off` (expert_source.cpp ~3976), the order
  copy_from_files assembles. `pool_tasks_test` gains an aarch64 check that split slices give the blob's bits. Side
  effect: the I/O counters (`reads_`, file bytes, page-cache held) stop counting zero-copy reads.
- How to judge (all warm profile, gate vs r3-baseline-w1/w2, automatic in ar_collect):
  | exp | switch | decides |
  | --- | --- | --- |
  | r3-e017-overlap-diag | overlap + timing + depth | vs e001: repetition `jobs` (e001 92-105 ms) should drop a little (the cold share), `CPU` (101-112) unchanged. Texts 1.0 or the pass split has a bug |
  | r3-e018-overlap | overlap | speed vs w1/w2. Keep only if rep or prose median beats its range (rep 14.1-15.7, prose 16.2-19.6 per request) and review >= 34.9 |
  | r3-e019-overlap-pool11 | overlap + `--pool-workers 11` | vs e012 (pool11 alone) and e018 |
  | r3-e020-zc-diag | zero-copy + timing + depth | vs e001: repetition `jobs` 92-105 -> expect ~10-25 ms; `CPU` may rise a few ms (the kernels read the mapping). Prose `jobs` 25-29 -> ~5-10 |
  | r3-e021-zc | zero-copy | speed vs w1/w2: expect rep ~15 -> ~20 (+30-40%), prose ~17.4 -> ~19-20, review unchanged (its misses are SSD-cold, so not zero-copied). Kill: any text change (a slice that is not the staged layout) or rep < +10% |
  | r3-e022-zc-overlap | zero-copy + overlap | with zero-copy, the cached misses compute while the cold ones read: the two compose |
  If zero-copy wins: repeat (rule 4), `--needles`, then commit with the review median first and the rep/prose
  numbers. It also lifts the mixed profile (e005: rep `jobs` 28-33 of 122-128 ms) and the T8 copy windows (e006).
- **Ranked next steps (iteration 4+):**
  1. `./ar_collect.sh`, then queue e020, e021, e022 at once (HEAD 3ea866a2, overrides written). They land after the
     ~12 runs ahead of them (~80 min).
  2. Judge e007-e016 by the iteration 1/2 tables, e017-e019 and e020-e022 by the table above.
  3. If zero-copy keeps texts and wins: the `jobs` remainder is 8 `std::thread` spawns a layer in `fill_many` (only
     the cold blobs now) and the mincore probes; the `CPU` part (101-112 ms on 4 of 12 cores) is next: combine with
     the best `--pool-workers` from e009/e010/e012.
  4. Code: B3a `STRATA_GU_SWIGLU` (review, ~+1%, research-ideas.md B3a).

### iteration 4 (2026-11-03 ~19:05-19:40 PST): e007-e016 collected and judged; zero-copy + A6 follow-ups queued
- Queued at 3ea866a2 (no source change this iteration): e020-e022 (iteration 3's zero-copy runs), then e027 and
  the A6 batch e023-e026 below.
- **r3-e007-mixlc7 (mixed + `--lookup-chain 7`): texts 1.0 vs r3-base-1/2 (compare.py by hand); review 31.35
  (8.95 stall / 31.35 / 32.59), prose 22.46, rep 29.70 = e005. Killed.** lookup-chain 4 and 7 are both closed.
- **r3-e008-vprof: texts 1.0 (PASS), review 33.89 (profiler on).** Per-stage table, review T4 (51-52 windows a
  request, 81.7-83.6 ms): experts **gate/up+SwiGLU 17.0** (GDN ~13.7 + QSA ~3.3; T1 6.4, T2 10.0, T3 13.3-14.0: it
  scales with distinct experts a layer, ~1.5 MB of gate/up each, so ~2.1 GB a T4 window = ~125 GB/s, ~60% of the
  Orin's 204.8 GB/s peak), VRAM-hit **down 9.2** (~117 GB/s), q8+qkv gemv 7.5, out-proj 5.8, hc1 up+router 4.8,
  head 4.8, shared+quant 4.6, z 4.2, HC (hc0/hc1 norm+down+up) ~10.4, attention 2.7, **waitCPU 2.5-4.3** (review's
  0.1% misses, SSD-cold: neither zero-copy nor overlap touches them; only placement does). So the expert kernels are
  26 of 82 ms and run at ~60% of peak bandwidth: B4 (gate/up rows per wave / EXPDEC) has more room than the
  +2-4% the plan gave it if the gap to ~170 GB/s is real; measure a gate/up-alone bandwidth probe before coding.
  (Blob sizes here are estimates from the 2.66 MB largest blob; check `expert_layout()` before relying on them.)
- **pool11 (r3-e009 timing, r3-e012 clean, r3-e011 + 16 I/O threads): texts 1.0 on all nine (PASS-class).**
  | exp | review (per request) | prose | rep (per request) |
  | --- | --- | --- | --- |
  | w1 / w2 | 35.17 (34.0/35.6/35.2) / 35.08 | 17.38 / 17.43 | 15.52 (14.1/15.7/15.5) / 14.24 |
  | e009 pool11 + timing | 34.45 (33.3/34.8/34.5) | 18.89 | 17.28 |
  | e012 pool11 | 34.73 (33.18/34.73/34.73) | 18.31 | 17.72 (16.6/18.1/17.7) |
  | e011 pool11 + io16 + timing | 34.72 | 17.59 | 17.28 |
  | e013 (= e001 repeat, iostage is a no-op) | 35.01 | 17.41 | 15.63 |
  Repetition +12-14% on every pool11 run (beats its 14.1-15.7 range), prose +1-8% (inside its range), review
  -1.2% (34.72-34.73 < the 34.9 bar; e009 vs e001: ~+1 ms a review window, GPU-reach 61-62 and host 3.2-4.9 vs
  2.7-4.2: the extra drainers cost the host thread a little). **Not kept as base (review bar)**; it stays the CPU
  half of the miss path for e027 (zero-copy + pool11). Repetition timing (e009 vs e001/e013): `CPU` halves (51-63
  vs 101-112 ms a window) but `jobs` rises (111-128 vs 92-105) because the policy, seeing cheaper windows, goes
  wider (avg T 4.0-5.0 vs 4.1, 9-10.5 entries a layer-window vs 9.3); per token 55-60 vs 70 ms. **e011: 16 I/O
  threads do not help** (jobs 124-143 vs 111-128): `jobs` is memcpy, not SSD (iteration 3's correction holds).
- **A6 adaptive tier (warm profile; texts change = REVIEW, slots 19,068 = match; no GPU errors, no
  `pressure_abort`, no adapt failure lines):**
  | exp | review (per request) | prose (per request, hits) | rep (per request, hits) | texts |
  | --- | --- | --- | --- | --- |
  | e014 every 16 | 32.23 (**24.0** / 32.2 / **36.6**) | **27.39** (21.1 93.4% / 27.4 99.1% / 27.6 99.4%) | **31.36** (23.0 92.1% / 31.4 98.4% / **34.8** 99.3%) | review 1.0/0.13/0.04, prose 0.02, rep 1.0 |
  | e015 every 64 | 33.88 (33.7 / 33.9 / 36.1) | 22.72 (18.1 / 22.7 / 24.0; 88-97.5%) | 24.02 (16.1 / 24.0 / 28.6; 82-94%) | review 1.0/0.36/0.04, prose 0.02, rep 1.0 |
  | e016 every 256 | 33.84 (33.8 / **28.7** / 34.1) | 18.23 (84-92%) | 18.79 (78-88%) | review 1.0/1.0/0.79, prose 0.02, rep 1.0 |
  - Why texts change: an expert the tier swaps in is then computed by the GPU instead of the CPU, and the two round
    differently (the engine's own startup note; same reason as slot drift). Review's prompt 1 keeps its text at
    every setting (its misses are swapped in only after it), repetition keeps all three (a copy task is robust),
    prose and review 2/3 change. Placement only: routing, top-k, math unchanged.
  - Prose and repetition learn within the session: hits climb 92->99% over the three requests at every 16, and the
    third repetition request runs 34.8 tok/s, as fast as review (it accepts more drafts). The three prose prompts
    share one vocabulary, so what request 1 teaches serves 2 and 3. **every 16 beats the mixed profile on prose
    and repetition (27.4 / 31.4 vs 22.6 / 29.7) and on review (32.2 vs 31.5)**, and leaves review's first request
    on the warm profile's text.
  - Review: the same-text requests show the cost. Request 1 at every 16 ran 24.0 (warm base 34.0 / 33.9; at 64
    and 256: 33.7 / 33.8), request 2 at 256 (identical routing counts to the base: 137,997 / 138,240) ran 28.7
    vs 35.4-35.6. Either the random PLE/SSD stall (2 in 15 base requests) or a blocking adapt round (the round's
    copies are joined after the draft, outside the timing line's terms, and the next window waits for them:
    `adapt_lag` 1). Requests with changed text run 32.2-36.6 and are not comparable. Unclear with 3 requests:
    e023 (trace) settles it.
  - Bench order matters and must be reported with any A6 number: review runs first, on the warm profile; prose
    and repetition inherit a cache review has already adapted. A server that saw prose before review would start
    review from a prose-adapted cache (not measured).
- Queued A6 batch (all warm profile, 3ea866a2; texts will differ from the warm gate: judge as REVIEW):
  | exp | change | decides |
  | --- | --- | --- |
  | r3-e023-adapt16-trace | every 16 + `STRATA_TRACE_ADAPT=1` + timing | swaps per round per workload (`ADAPT choices count=`), where the rounds fall (`ADAPT schedule/queued position=`), and whether review's slow requests line up with large rounds (wall time per request minus windows x ms/window = the time outside the window: adapt joins + stalls) |
  | r3-e024-adapt16-lag2 | every 16 + `STRATA_ADAPT_LAG=2` | the copies land one window later (deterministic by window count, generate.cpp:1576): if review's dip is the wait for the copies, review recovers to >= 34.9 while prose/rep stay ~27/31 |
  | r3-e025-adapt16-sw32 | every 16 + `--adapt-swaps 32` | smaller rounds: review cost vs prose/rep learning speed |
  | r3-e026-adapt8 | every 8 | faster learning: prose/rep first-request speed (21.1 / 23.0 at 16) vs review cost |
  | r3-e027-zc-pool11 | zero-copy + `--pool-workers 11` (PASS-class) | vs e021 (zc alone) and e012 (pool11 alone): the two halves of the repetition miss window (`jobs` copy, `CPU` compute) together. Keep rule as e021, and review must hold >= 34.9 |
  A6 becomes a base candidate (owner REVIEW: new gate baselines, as for the mixed profile) only if a variant keeps
  review >= 34.9 on its median and on its same-text request 1, with pr_mean >= ~27, no GPU errors or aborts; then
  repeat + `--needles`.
- **r3-e010-pool7 (`--pool-workers 7` + timing; collected 19:35): texts 1.0 on all nine (PASS-class), 19,068
  slots; review 35.11 (33.85 / 35.11 / 35.46), prose 19.29, rep 18.83.** Better than pool11 on all three. Review
  windows 75.2-76.0 ms (= e001's 75.5-76.1; pool11 76.6-77.4), so 7 workers do not tax the host thread the way 11
  do. Repetition: `CPU` 40-58 ms a window (e001 101-112), `jobs` 64-107, 51-56 ms a token (e001 ~70). Prose: host
  45-59 [jobs 28-33, CPU 16-25] vs e001 59-79. Rep +21% and prose +11% over w1/w2 with review unchanged (timing
  on costs ~0.5%, so clean review should be ~35.3). Rule 4: it does not beat review's best beyond the spread, so
  it is not a headline improvement; it is a PASS gain on prose/repetition. Queued r3-e028-pool7-clean (the repeat)
  and r3-e029-zc-pool7 (with zero-copy). **If e028 confirms (review >= 34.9, rep above 15.7 and prose above
  17.4 on the median): commit nothing (settings only) and make `--pool-workers 7` part of the recommended base in
  this file's top block; the owner applies it to `base-overrides.json` (not an agent-editable file).**
- **Ranked next steps (iteration 5+):**
  1. `./ar_collect.sh`; judge e017-e019 and e020-e022 by "iteration 3", e023-e029 by the tables above. For the
     zero-copy runs, compare against pool7 (e028/e029) as well as w1/w2.
  2. If zero-copy keeps texts: it composes with pool11 (e027) and with the adaptive tier (prose/rep misses that
     remain after adapting); queue zc + every 16 (+ lag 2 if e024 wins).
  3. If e023 shows review's slow requests are adapt rounds and lag 2 does not fix them: a code item, the adaptive
     round's blob reads (`blob_stable` of up to 96 non-resident experts, on the critical path through the join)
     moved to the io prefetch threads one round ahead, or `--adapt-accepted-only`.
  4. Code: B3a `STRATA_GU_SWIGLU` (review, ~+1%), then a gate/up bandwidth probe for B4 (e008: ~60% of peak).

### iteration 5 (2026-11-03 19:01- PST by `date`; iteration 4's clock times above run ~40 min ahead): B3a built and queued
- Nothing to collect at start (e017 running, 12 pending, ~80 min of queue). Item: B3a (ranked step 4).
- Path check (code read): decode's VRAM-hit experts go verify.cpp:2285 -> `native_expert_grouped` with gy =
  `STRATA_VRAM_GY` 8; on CUDA `em0` = `exp_mode()` = 0 (`kExpModeDefault` 0), so gate/up is `launch_gu<21>` ->
  `native_gu_multi_kernel<21, false, true, true>` (16-lane rows + `STRATA_EXP_PF`), then
  `swiglu_q8_1_entries_kernel` (`v1` false). `STRATA_EXPERT_V2` (the S26 path) is not set in the base. IQ3_S is not
  grid-staged (`kStageIqGrid<21>` false). The MTP draft experts (gate/up IQ4_XS = type 23) do not take the new path.
- Real sizes (block_iq3_s 110 B / 256 values, block_iq4_nl 18 B / 32): gate/up row 1,100 B, **gate + up 1.408 MB an
  expert; down 360 B a row x 2,560 = 0.92 MB** (iteration 4's B4 note assumed 0.75 MB). With e008 (T4: gate/up+SwiGLU
  17.0 ms, down 9.2 ms): bytes 1.53 : 1, time 1.85 : 1, so **gate/up runs ~20% slower per byte than down**; at down's
  per-byte rate it would take ~14.1 ms: ~3 ms a T4 window (~3.5%) is the gate/up-specific gap (B4's real size
  until a bandwidth probe says more). Down itself: 0.92 MB x ~30 experts x 48 / 9.2 ms = ~144 GB/s.
- **Code (commit 99f5d04c, PENDING, opt-in `STRATA_GU_SWIGLU`)**: `native_gu_swiglu_kernel<21, PF>` (iq_kernels.cu,
  after `swiglu_q8_1_entries_kernel`), a port of upstream's 147-verify kernel. 512-thread block = 32 hidden columns;
  sub-warp sw computes gate row r and up row r with new `row_dot2_80_sub16` (row_dot_80_sub16's loads, sums and xor
  tree per row; both rows' loads issued together); lane c (c < n) writes entry c's
  `__fmul_rn(g / (1 + __expf(-g)), u)` (the separate kernel's exact expression) to shared; warp k runs `q8_1_store`
  on entry k's 32 columns, lane = column % 32 as in the separate kernel (n_ff % 32 == 0, so its warps were whole q8_1
  blocks with the same lane order). Same entries ([grp_start[0], grp_start[ng])). `=1` with `STRATA_EXP_PF` on
  prefetches the block's next group (32 gate + 32 up rows) into L2, `=2` without. Grid (n_ff/32 = 20, gy 8) = 160
  blocks of 512 (the multi kernel: 640 of 256); `__launch_bounds__(512, 2)` caps 64 registers: two IQ3_S `W`
  structs (10 registers each) + 16 accumulators may spill (bitwise anyway; `STRATA_BW_PROBE=1` prints registers and
  local bytes for both variants). Taken only on em0 0, phase 0, not v1, gate/up type 21, n_embd 2560.
- Queued (all warm profile, gated vs r3-baseline-w1/w2):
  | exp | switch | decides |
  | --- | --- | --- |
  | r3-e030-gusw | `STRATA_GU_SWIGLU=1` | review vs w1/w2 (35.17/35.08), e013 (35.01); texts 1.0 on all nine |
  | r3-e031-gusw-prof | `=1` + `STRATA_VERIFY_PROFILE` + timing | vs e008: the experts gate/up+SwiGLU row at T4 (17.0 ms, 51-52 T4 windows a request) and T1-T3 (6.4/10.0/13.3-14.0) |
  | r3-e032-gusw-nopf | `=2` (no L2 prefetch) | vs e030: does the prefetch pay in the fused kernel |
  Keep (commit as `decode X: ...`, then repeat + `--needles`) only if texts are 1.0 on all nine and review beats
  35.27 (best + spread) on the median; a row drop >= 0.3 ms in e031 with review inside the spread = queue a repeat
  and a `STRATA_VRAM_GY` 16 variant (the fused grid has 1/4 the blocks, so gy 8's optimum may move) before judging.
  Kill: any text change (an ordering slip: compare `row_dot2_80_sub16` with `row_dot_80_sub16` first) or a row drop
  < 0.1 ms with no review gain.
- Probes (ahead of the queue, same build 99f5d04c, engine-level on the fixed 4,096-token prompt, `--max-new 128
  --window-hashes`): r3-p010-wh-base (switch off) vs r3-p011-wh-gusw (`=1`). Identical `wh.txt` = bitwise on the
  windows of one request (valid only if both report the same cache slots).
- **r3-e017-overlap-diag (`STRATA_MISS_OVERLAP=1` + timing + depth, collected 19:08): texts 1.0 on all nine, 19,068
  slots (PASS-class); review 35.09, prose 17.49, rep 15.23 = w1/w2 and e001.** Repetition per request: jobs 93.7 /
  80.2 / 76.7 ms, CPU 112.6 / 94.9 / 88.6 a window (e001: 91-105 / 101-112); 64.9-69.3 ms a token (e001 ~70): no
  gain beyond the spread. As iteration 3 predicted (the decode misses are page-cache hits, so there are few cold
  reads to hide). The engine prints no line when the switch is on (env confirmed in args.txt). Overlap is closed
  unless e018/e019 disagree; zero-copy (e020-e022) is the `jobs` lever.
- **Ranked next steps (iteration 6+):**
  1. `./ar_collect.sh`; judge e018-e029 by iterations 3/4, e030-e032 by the table above. If r3-p010/p011 came back
     (runs/r3-p01{0,1}-*/wh.txt), `diff` the two wh.txt files first: a difference with equal cache slots means the
     fused kernel is not bitwise: revert 99f5d04c's switch use (keep the commit, note it) before reading e030-e032.
  2. If GU_SWIGLU holds texts and helps: repeat + `--needles`, then commit `decode X: ...`; queue `STRATA_VRAM_GY` 4
     and 16 with it. If the gate/up row drops by more than the SwiGLU launch, B4 = 4 rows a sub-warp (research-ideas
     B4 note, iteration 5 correction).
  3. pool7 (e028) and zero-copy (e021/e027/e029): if both confirm, the PASS-class prose/repetition base is
     `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1`: write it in the top block for the owner.
  4. Code, review: B3's remaining independent items, in plan-review order: `SIDE_MIXER=2` (M; exclusive with our
     `df_branch_` draft branch upstream: measure with and without), then `COMMIT_BATCH` (S). `QSA_ROWS` gains mainly
     at 131K contexts (plan-review item 7): last.
  5. B1a (rows table at T5-T8 + `STRATA_BW_PROBE` rows) before any B1 kernel code.

### iteration 6 (2026-11-03 20:36- PST by `date`): every run since e018 was a stale build; rebuilt, re-probed
- `./ar_collect.sh` logged e019-e032 (14 runs): all `no_result`, `supervisor: fail`, and all on **one exe,
  a80b089d**, whatever their source: e019 is af6a5faa, e020-e029 3ea866a2, e030-e032 99f5d04c. In each engine.log
  the engine starts 3 times (server.py restarts it). Every start ends at `captured the 6-token window`, before the
  first request's `capturing the 1-token window`. Probes r3-p010..p013 (99f5d04c, run while iteration 5 was still
  going, never recorded) exit with **rc -11 (SIGSEGV)** right after `captured the 4-token window`, at the first
  decode window. That includes p010 and p012 with every switch off.
- Cause: stale or mixed builds (harness warning in the top block). Timeline: 3ea866a2's 8 files were committed at
  18:01. e017 (af6a5faa) was built at ~18:57, so those files were older than its objects. p010 (the first job at
  99f5d04c, 19:13) ran 8 compiles and relinked libstrata_kernels.a and libstrata_engine.a. Every later job printed
  `ninja: no work to do`, e019's af6a5faa snapshot included. 3ea866a2 adds a virtual to `ExpertSource` (`slice`,
  between `pages_cached` and the predictor hooks) and two pointers to `ExpertJobMulti`. A binary whose files saw
  different versions of those headers calls the wrong vtable slot or misreads job structs: a host segfault on the
  first CPU-miss window fits. Not proven: the build log keeps only its last 40 lines, so which 8 files p010
  compiled is unknown. The off-switch code in 99f5d04c (`launch_gu_swiglu` returns false when
  `g_gu_swiglu == 0`; the separate launches are guarded by `!gs_done`) and in 3ea866a2 (null `up`/`down` = the
  old addresses) reads as unchanged.
- Fix applied: commit 625b9ae0, comment-only edits to the three headers 3ea866a2 changed (expert_source.hpp,
  pool.hpp, native_expert.hpp; expert_layout.cpp reaches native_expert.hpp through expert_layout.hpp). Ninja's
  depfiles then rebuild every file that includes them. iq_kernels.cu includes none of them and already holds
  99f5d04c's content from p010.
- Probes at 625b9ae0 (prio 0, ahead of everything): r3-p014-head-wh (overrides r3-p010-wh-base.json, switch off)
  and r3-p015-head-wh-gusw (`STRATA_GU_SWIGLU=1`), both `--max-new 128 --window-hashes {RUN}/wh.txt`.
  Results below.
- **r3-p014-head-wh (625b9ae0, every switch off): no crash.** The build ran 19 steps, ending with prefill.cpp and
  generate.cpp (p010: 11). The probe decoded 128 tokens at 32.15 tok/s; that is an engine-level probe that includes
  the first windows' graph captures, so it is not comparable to bench numbers. 53 window hashes in wh.txt; 19,068
  slots; exit 0. **So the e019-e032 failures were the stale/mixed build, not 3ea866a2's or 99f5d04c's code.**
- **r3-p015-head-wh-gusw (`STRATA_GU_SWIGLU=1`, same binary): wh.txt identical to p014 (`diff` empty, 53
  windows), 19,068 slots in both, exit 0; decode 31.88 vs 32.15 tok/s (single probes, noise).** The fused kernel is
  bitwise on every window of the fixed review request, provided it ran. The engine prints nothing when the switch is
  on, so confirm in e038: the profile's experts gate/up+SwiGLU row should move against e008's 17.0 ms at T4. If
  it does not move at all, check the path conditions (em0 0, phase 0, not v1, type 21, n_embd 2560) before
  believing e035.
- Re-queued at 20:46, all at 625b9ae0+0 (one source state, behind the two probes; the overrides are the invalid
  runs' files, unchanged). **First check: every row's exe_sha256 must be one new value, not a80b089d. If p014
  segfaults again (probe-tail `returncode: -11`), all eight are invalid: see "if p014 crashes" below.**
  | exp | = invalid run | decides (rules from iterations 3-5) |
  | --- | --- | --- |
  | r3-e033-pool7 | e028 | rule-4 repeat of e010. Confirmed if texts are 1.0 on all nine, review >= 34.9, rep > 15.7 and prose > 17.4 on the median. Then write `--pool-workers 7` into the top block as the recommended PASS-class base for the owner (settings only, no commit) |
  | r3-e034-zc | e021 | expect rep ~15 -> ~20, prose ~17.4 -> ~19-20, review unchanged. Kill on any text change or rep < +10% |
  | r3-e035-gusw | e030 | keep only if texts are 1.0 on all nine and review > 35.27 on the median; then repeat + `--needles` |
  | r3-e036-zc-pool7 | e029 | zero-copy and pool7 compose: the `jobs` and `CPU` halves of the repetition miss window |
  | r3-e037-zc-diag | e020 | vs e001: repetition `jobs` 92-105 ms -> ~10-25; `CPU` may rise a few ms |
  | r3-e038-gusw-prof | e031 | vs e008: the experts gate/up+SwiGLU row at T4 (17.0 ms) and T1-T3 (6.4 / 10.0 / 13.3-14.0) |
  | r3-e039-adapt16-lag2 | e024 | A6, REVIEW class: review recovers to >= 34.9 with prose/rep ~27/31? |
  | r3-e040-adapt16-trace | e023 | A6: swaps per round per workload; do review's slow requests line up with rounds? |
  Not re-queued: e019 and e022 (overlap is closed: e017/e018 = baseline), e027 (pool11 loses to pool7), e025 /
  e026 (A6 swaps 32 / every 8: after lag2 and the trace), e032 (gusw=2: only if e035 pays).
- If p014 crashes: the full HEAD build has a real off-switch bug. Wait for the queue to empty (eight crashing
  benches, ~6 min each), then bisect in order. (a) `git revert --no-commit 99f5d04c` and probe; the revert writes
  iq_kernels.cu, so its mtime is fresh. (b) If that still crashes, revert 3ea866a2 as well. A crash in 3ea866a2
  would most likely be a job slot whose `up`/`down` is set on one path and not reset on another.
- **Ranked next steps (iteration 7+):**
  1. `./ar_collect.sh`. Check exe_sha256 (one new value across e033-e040), then judge by the table above. p014 vs
     p015 `wh.txt`: identical with equal cache slots = the fused kernel is bitwise on the windows of one request.
  2. If e033 confirms pool7 and e034/e036 confirm zero-copy (texts 1.0): the PASS-class prose/repetition base is
     `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1`. Repeat e036 with `--needles`, commit `decode X: ...` (zero-copy
     stays opt-in), and write the recommendation in the top block for the owner (base-overrides.json is the owner's).
  3. A6: if lag 2 keeps review >= 34.9, repeat it + `--needles` as the REVIEW candidate, then zc + every 16 + lag 2.
     `STRATA_ADAPT_NOWAIT=1` (generate.cpp:1570; upstream's sm_86 stack credits it with 6.3 points on an A4000)
     exists in our tree. But whether a swapped-in expert runs on the GPU or the CPU then depends on copy timing, so
     texts are not reproducible run to run. Measure it only after lag 2, and report its texts as REVIEW from at
     least two runs.
  4. Code, review: GU_SWIGLU result first (e035/e038). Then upstream `STRATA_COMMIT_BATCH` (upstream-strata.md 3.3:
     commit `6f3e38100`, 352 lines / 7 files, +0.5-1.5%) or `SIDE_MIXER=2` (3.1, M, exclusive with our `df_branch_`).
     Upstream today: `research-engines/Strata/src/core/verify.cpp:2934-2999`. Every GDN layer's conv history and
     state go in two launches (`gdn_commit_layers`), and the QSA tail restore + indexer append in one
     (`QsaIndexerLayers`, one block per layer). Neither exists in our tree. Upstream's kernels live in
     `src/kernels/cuda/verify_kernels.cu` + `include/strata/kernels/{verify_kernels,native_qsa_indexer}.hpp`
     (parity test: `src/kernels/gdn_parity.cpp`). Keep the per-layer `ssm_norm.weight` check. Opt-in here
     (`STRATA_COMMIT_BATCH=1`), unlike upstream's default on.
     One source state at a time (harness rule 1).

### iteration 7 (2026-11-03 20:50- PST by `date`): pool7 confirmed; B6a COMMIT_BATCH built and queued
- **r3-e033-pool7 (625b9ae0, exe 46732e1c, `--pool-workers 7`, no timing): PASS, texts 1.0 on all nine, 19,068
  slots; review 35.05 (34.04/35.65/35.05), prose 21.01 (22.2/15.15/21.01), rep 18.57.** It confirms e010 (35.11 /
  19.29 / 18.83) by iteration 4's rule (review >= 34.9, rep > 15.7, prose > 17.4 on the median). Settings only, so
  nothing to commit; the top block now recommends it for the owner's base. The exe differs from the stale a80b089d,
  so the 625b9ae0 rebuild took. (`supervisor: fail` is in every result.json, the baselines' too: not a signal.)
- Item: B6a = upstream `STRATA_COMMIT_BATCH` (ranked step 4). No probes: `ar_probe.sh` jumps the queue (priority 0),
  so a probe of a new source state ahead of e034-e040 would make those 625b9ae0 snapshots run the new binary
  (harness warning). Benches only, behind e040.
- Code read: our `Verifier::capture_commit` (verify.cpp ~2727) launches, per GDN layer, `gdn_conv_commit` +
  `gdn_step_norm_multi(..., t_out_begin = MT)`, which with the base's env (no `STRATA_GDN_SPLIT`,
  `STRATA_GDN_COMMIT_SPLIT` default on) is `gdn_step_commit_kernel<false>` (grid h_v x 4, block 32 x RG). Per QSA
  layer: `copy_from_mapped(tail <- tail_snap_)`, `native_qsa_indexer_append_steps(commit_ + 2, stride 1, MT steps,
  pos_base 0)`, `native_qsa_indexer_restore_spare(commit_, MT)`. Our kernels' bodies are textually upstream's
  (`gdn_step_commit_body`, `append_body`); upstream has no `restore_spare` (it left our lineage), so the batched QSA
  kernel here adds it. The per-layer buffers are linear in the GDN / QSA index (state + i * gdn_floats, conv at
  + state floats; qkv/h at i * MT * C; gate/beta at i * MT * HV; idx_raw at i * MT * ID; tail_snap_ at i * TS), and
  no two layers share a buffer, so batching only reorders independent writes: bitwise by construction.
- **Code (commit cbe51765, PENDING, opt-in `STRATA_COMMIT_BATCH=1`)**: `gdn_commit_layers` (verify_kernels.cu:
  `gdn_conv_commit_layers_kernel`, blockIdx.y = layer; `gdn_step_commit_layers_kernel`, blockIdx.z = layer) and
  `native_qsa_indexer_commit_layers` (one 256-thread block per QSA layer: tail copy, `__syncthreads`, `append_body`,
  `__syncthreads`, `restore_spare_body`; `QsaIndexerLayers` holds up to 16 layers' pointers). The three old kernels
  now call the shared forceinline bodies (same text, as upstream did). Fallback to the per-layer loop when the
  per-layer commit would pick another kernel (`STRATA_GDN_SPLIT=1`, `STRATA_GDN_COMMIT_SPLIT=0`, `STRATA_DBG_GDN=1`),
  with `g_no_batch_kv`, or if QSA layers differ in `max_cells`. engine.log gets one line: `strata verify:
  STRATA_COMMIT_BATCH=1: GDN commit batched (N layers), QSA commit batched`: check it in e041 before reading speed.
  Launches: 2 per GDN layer + 3 per QSA layer -> 3 in all. Expected gain small: the GDN state commit moves ~2-3 MB a
  layer each way, so it is mostly bandwidth; round 2 put the commit at 1.57 ms a window, ~1.2 ms on the critical
  path; expect -0.2 to -0.6 ms a window (+0.3-0.8%), which may sit inside review's spread.
- Queued (warm profile, gated vs r3-baseline-w1/w2):
  | exp | switch | decides |
  | --- | --- | --- |
  | r3-e041-cb | `STRATA_COMMIT_BATCH=1` | texts 1.0 on all nine vs f1/f2 (else the batching has a pointer/stride bug: compare strides with the per-layer loop); review vs f1/f2 and e043 (same binary, same memory conditions) |
  | r3-e042-cb-diag | `=1` + timing + depth | vs e001 (same overrides minus the switch): review ms/window (e001 75.49-76.06). The commit graph runs beside the draft round, so its GPU time shows in `draft` (e001 5.91-6.08 ms) and the next window's `GPU-reach wait` (60.95-61.67), not in `commit/emit` (0.04-0.06, host only) |
  | r3-e043-cb-off | switch off, same binary | texts 1.0 = the refactored default kernels are unchanged (window graphs use `append`; the per-layer commit uses the other two); same-binary speed comparator for e041 |
  Keep rule: texts 1.0 on e041, e042, e043, and either review e041 > f1/f2's best + spread on the median, or e042's
  review ms/window >= 0.3 ms below e001's at equal avg T with e041 >= e043 (e001 ran at 19,068 slots: if f1/f2's
  slots differ much, compare e042's window time with e043's instead, which has no timing line, by request wall time). Then repeat + `--needles` and commit
  `decode X: ...` (switch stays opt-in). Kill: any text change (revert cbe51765's verify.cpp branch; the kernel
  refactor alone is harmless only if e043 passes) or no window-time drop (< 0.1 ms).
- Collected 21:15 (all 625b9ae0, exe 46732e1c, 19,068 slots, all started before the owner's 21:12 memory change, so
  gated vs w1/w2):
  | exp | switch | review (per request) | prose (per request) | rep (per request) | texts | verdict |
  | --- | --- | --- | --- | --- | --- | --- |
  | r3-e034-zc | zero-copy | 35.17 (34.05/35.54/35.17) | 18.22 (21.63/18.22/16.16) | **20.01** (17.57/20.01/20.70) | 1.0 all nine | zero-copy works: rep +29% over w1 (iteration 3's ~20 prediction), review unchanged. Keep (opt-in, already committed in 3ea866a2) |
  | r3-e035-gusw | `STRATA_GU_SWIGLU=1` | 34.88 (33.68/35.26/34.88) | 17.66 | 15.23 | 1.0 all nine | bitwise (with p014/p015) but no review gain (< 35.27, below w1/w2). e038's profile row decides whether it is worth a GY sweep; else close |
  | r3-e036-zc-pool7 | zero-copy + pool7 | **35.46** (33.97/35.46/35.65) | **24.31** (27.19/24.16/24.31) | **29.93** (29.93/30.96/29.62) | 1.0 all nine | the two halves compose: rep x1.93, prose +40% over w1/w2; review +0.8% on one run. Repeat = e044 (+ needles) |
  Zero-copy removes the miss path's copy (`jobs`) and pool7 its compute wait (`CPU`); each alone gives rep ~19-20,
  together ~30, because the policy then widens repetition windows (iteration 4 saw the same feedback on pool11).
  Prose and repetition are still miss-bound (77-90% hits): placement (A6) is the next lever on top of this.
- **Ranked next steps (iteration 8+):**
  1. `./ar_collect.sh`; judge e037-e040 by "iteration 6" (exe 46732e1c), e041-e044 by the table above (exe one new
     value). Runs after 21:12 compare only with r3-baseline-f1/f2 (owner note in the top block). Prose/repetition
     comparisons should also use e036 (24.31 / 29.93).
  2. If e044 confirms zc + pool7 (texts 1.0 vs f1/f2, needles 3/3, rep and prose within ~10% of e036): empty commit
     `decode X tok/s: --pool-workers 7 + STRATA_MISS_ZEROCOPY=1 ...` naming e036/e044, and the top block recommends
     both for the owner's base. Then A6 on top: zc + pool7 + `--adapt-every 16` (+ lag 2 if e039 wins), REVIEW class.
  3. GU_SWIGLU: only if e038 shows the gate/up+SwiGLU row >= 0.3 ms below e008's 17.0 at T4; then one
     `STRATA_VRAM_GY` 16 run with it. Otherwise closed (bitwise, no gain).
  4. A6 (e039/e040): as "iteration 6" step 3; if review recovers with lag 2, next is zc + pool7 + every 16 + lag 2.
  5. Code, review: B4/EXPDEC after a gate/up bandwidth probe (e038's row first). **`SIDE_MIXER=2` is demoted**: our
     tree's version of the same idea, `STRATA_DF_BRANCH=1` (verify.cpp:1280; GDN a/b + z and QSA q / indexer q on
     side streams inside the graph), was measured in round 1 (r1 notes.md:613, e072) at +2.5 to +3.1 ms a window
     with texts identical: two GEMVs at once compete for the 16 SMs that each already fills. SIDE_MIXER moves only the
     small gate / indexer-key projections, so it could differ, but start from e072's evidence: only try it after
     B4, and kill it on the first run if review ms/window rises.

### iteration 8 (2026-11-03 21:17-21:35 PST by `date`): f1 + e037 collected; B7 STRATA_SPEC_COST built and queued
- **r3-baseline-f1** (cbe51765, switches off): see the top block (19,068 slots, texts 1.0 vs w1/w2, review 35.47).
- **r3-e037-zc-diag (`STRATA_MISS_ZEROCOPY=1` + timing + depth, 625b9ae0, exe 46732e1c, 21:27): PASS, texts 1.0
  on all nine, 19,068 slots; review 35.57 (34.44/35.57/36.48) with timing on, prose 20.75, rep 22.0.** The review
  texts equal e001's, so the window mix is identical (T1/T2/T3/T4 = 18/13/16/51, 13/20/10/51, 12/17/15/52 a
  request): a clean same-windows A/B against e001 (timing + depth, no zc):
  | review request | e001 ms/window | e037 ms/window | e001 host [jobs / CPU] | e037 host [jobs / CPU] | e001 T4 round | e037 T4 round |
  | --- | --- | --- | --- | --- | --- | --- |
  | 1 | 75.71 | **74.34** | 2.83 [2.19 / 0.35] | 1.42 [0.72 / 0.42] | 86.60 | 84.75 |
  | 2 | 76.06 | **73.86** | 4.17 [3.23 / 0.60] | 1.72 [0.69 / 0.73] | 87.50 | 84.51 |
  | 3 | 75.49 | **74.19** | 2.74 [2.02 / 0.41] | 1.25 [0.40 / 0.48] | 86.08 | 84.30 |
  **Zero-copy cuts review's windows by 1.3-2.2 ms (-1.7 to -2.9%)**: iteration 3's "review's misses are SSD-cold, so
  zero-copy does not touch review" was wrong. Most of review's `jobs` (2.0-3.2 ms) was the assembly copy of
  page-cached misses, now 0.4-0.7 ms; verify T4 77.5-77.9 vs 79.3-80.9. This is the mechanism rule 4 asked for
  behind e036's 35.46: zc + pool7 should land review ~+2% (~36.0-36.2 clean). e044 (zc + pool7 + needles) is the
  repeat; if its review median is >= ~35.9 with texts 1.0, commit it as the new review best (settings only: empty
  commit) and recommend both switches for the owner's base.
  Prose (e037, zc alone): host 36-55 ms a window, `CPU` 32-49 of it, `jobs` only 3.8-6.3: with zero-copy the prose
  miss path is the CPU compute (pool7's half). Repetition: `CPU` 93-120 ms of 164-204 ms windows.
- Item: **B7 = upstream `STRATA_SPEC_COST`** (ranked step 5's B4 replaced: round 1 already closed gate/up "loads in
  flight" (e038/e039), activations staged in shared memory (e040, +0.6 ms; EXPDEC's core idea) and found the
  decode kernels issue-bound (p041/p042), so B4/EXPDEC is demoted below B7 and B2).
- Window economics, review (e001/e037 `by window size`, round ms incl. the next draft): tokens per ms T1 0.019, T2
  0.027-0.029, T3 0.030-0.032, **T4 0.040-0.042**; 45% of windows (T1 12-18, T2 13-20, T3 10-16 a request) stop
  below T4 under min-p 0.5 + `STRATA_SPEC_CUM 0,0.40,0.47`. Prose (e037): T4 0.021-0.026 vs T3 0.021-0.025, T2
  0.019-0.024 (CPU misses grow with the window). Repetition: T4 ~0.023, T6 lookups ~0.022. A rule that prices
  each width per workload with learned acceptance could move some T2/T3 windows on review to T4 and pick
  narrower windows on prose; the static gate was tuned on review in round 2, so expect 0 to +2% on review.
- **Code (commit af839e5b, PENDING, opt-in `STRATA_SPEC_COST=1`)**: `DraftPolicy` (draft_policy.hpp/.cpp) gains
  upstream's `keep_draft` / `observe_probs` / `draft_rate` (8 probability buckets, prior = p worth 4 rounds, decay
  0.995), `seed_costs` and `set_robust` (a round clamped at 2x its width's known cost, first samples a running
  mean; a width's first round, its graph capture, takes the scaled guess). No context buckets (the bench runs at
  ~4K). `MtpDrafter::set_chain_rule` replaces the min_p / cum test in draft()'s stepwise loop (mtp.cpp ~1584) by
  rule(j, p_j) after each draft. generate.cpp serve loop: the rule is set once per process (the policy is
  process-wide, so costs learned on review carry into prose and then repetition; EMA 0.1, ~20 windows to adapt);
  `chain_rows` is reset before each `mtp.draft` and, when the rule ran, sets T (else the old test); after an MTP
  window (no lookup, no chain) `observe_probs(dwin, T - 1, a)` teaches the calibration. Default path unchanged
  (empty rule = the old test; chain_rows stays 0). One stderr line at startup: `STRATA_SPEC_COST=1: MTP windows of
  up to 4 rows ... (costs ... ms at 1-4 rows before any round)`: check it in e045's engine.log first.
  `STRATA_SPEC_COST_TABLE=52.5,63.5,74.5,86.7` (e001 round ms at T1-T4) seeds the costs, worth 6 rounds each.
- Queued at af839e5b (21:25, behind e044):
  | exp | switch | decides |
  | --- | --- | --- |
  | r3-e045-scost | `=1` + table | texts 1.0 on all nine (any change = a bug: windows are verified exactly and e002-e004 showed texts do not depend on the window); review median vs f1 35.47 / w1-w2 35.08-35.17 |
  | r3-e046-scost-diag | `=1` + table + timing + depth | vs e001 (same overrides minus the switch): tokens/window and ms/window per request -> tokens per ms (e001 0.0338 / 0.0354 / 0.0350); the T histogram (e001 T4 51-52 a request); prose/rep window mix vs e001 |
  | r3-e047-scost-zcp7 | `=1` + table + zc + pool7 | prose/rep vs e036 (24.31 / 29.93) and e044; review vs e044 |
  Keep: texts 1.0 on all three runs, and either review e045 > ~35.7 (f1 + spread) with e046's tokens per ms >= 2%
  above e001's, or e047 beats e044 by > 10% on prose or repetition with review not lower. Then repeat + `--needles`
  and commit `decode X: ...` (switch stays opt-in). Kill: e046's tokens per ms within 1% of e001's and e045/e047
  inside the baselines' spread. If it loses on review only, try `STRATA_SPEC_COST_TABLE` unset (learned costs)
  before closing.
- **Ranked next steps (iteration 9+):**
  1. `./ar_collect.sh`; judge e038-e044 by iterations 6/7 and e045-e047 by the table above (check exe_sha256: e045 a
     new value). e044 is the headline candidate now (zero-copy's review mechanism above).
  2. If e044 confirms: empty commit `decode X tok/s: --pool-workers 7 + STRATA_MISS_ZEROCOPY=1 ...` (e036, e037,
     e044), top block recommends both for the owner's base; from then on every review run should carry both.
  3. A6 on top of zc + pool7 (e039/e040 decide lag 2), REVIEW class.
  4. Code, review: B2 (HC 2-phase down+up fusion, plan-review item 6: judge in a served `STRATA_VERIFY_PROFILE` run,
     +2-4%) or B1a (rows table for 5-8 columns; e004 says wide windows lose only through the T5/T7 cliffs).
  5. Review's remaining host time with zc is ~1.3-1.7 ms a window (plan 0.18, jobs 0.4-0.7, CPU 0.4-0.7): small.
     The GPU-reach wait (61-62 ms) is the review lever: kernels (B1/B2) and the window policy (B7).

### iteration 9 (2026-11-03 21:29- PST by `date`): A8 bigger expert cache + A6 combos queued (settings only)
- `./ar_collect.sh` at 21:29: nothing new (r3-baseline-f2 running, 10 pending). No source change this iteration;
  engine tree clean at af839e5b.
- **Finding (code read): the cache size is set by `--expert-cache 14629`, not by free memory.** generate.cpp:4933-4956
  (native pack + profile, the path the base takes): `budget = N x max_blob` (2.539 MiB, so 14,629 = 36.27 GiB), then
  `cap = min(budget, device_free - 700 MiB)` (keep_free = `--vram-reserve-mib`, default 700; the 3,072 MiB reserve
  at :4768 is only for the auto size, N < 0), and slots are taken in profile order at each layer's own blob size
  until `cap`: 19,068 slots. f1/f2 had ~49 GiB free before the cache, so the budget, not memory, bound. An explicit
  N whose allocation fails makes the engine exit (only the auto size shrinks and retries, :5043): a `no_result`
  in e048-e054 with an allocation error in engine.log means the size was too big for that start.
- Memory arithmetic: run_control.py aborts below 6 GiB MemAvailable (bench.sh:3). f1/f2 min free 11.92 / 12.04 GiB;
  w1/w2 (before the owner freed memory) ran fine at 7.06-7.08. `--expert-cache 16400` adds 1,771 x 2.539 MiB = 4.39
  GiB: min free ~7.6 GiB (expect ~21.3K slots, ~87% of the 24,576 pairs); 15,500 adds 2.16 GiB (~20.2K slots, min
  free ~9.8). 16,800+ would sit within ~0.5 GiB of the abort floor: not queued.
- Why it can pay: the extra ~2.3K slots are the warm profile's next-ranked pairs. Review's remaining misses are
  0.1 CPU experts a layer-window (host 1.25-1.72 ms a window with zero-copy, e037; plus the SSD-cold ones behind
  the stalls); prose/repetition miss 10-21% of lookups. Texts change wherever a newly cached expert is routed (the
  GPU rounds differently from the CPU), so every run but e053 is REVIEW class by design.
- Queued at af839e5b+0 (21:33; same source state as e045-e047, so no rebuild; every af839e5b switch off):
  | exp | settings (all `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1`) | compare with | decides |
  | --- | --- | --- | --- |
  | r3-e048-c16400-zcp7 | `--expert-cache 16400`, warm | e036 / e044 (zc + pool7 at 19,068) | slots (engine.log `expert cache N slots`), min free, hits per workload, speed on all three |
  | r3-e049-c16400-zcp7-rep | same as e048 | e048 | REVIEW evidence: `python3 compare.py runs/r3-e049-c16400-zcp7-rep/result.json runs/r3-e048-c16400-zcp7/result.json` must give 1.0 on all nine at equal slots; also rule 4's repeat |
  | r3-e050-c15500-zcp7 | `--expert-cache 15500`, warm | e048 / e036 | dose-response: does half the extra cache give half the gain |
  | r3-e051-c16400-zcp7-diag | e048 + timing + depth | e037 (zc, 19,068) | review host [jobs / CPU] and CPU experts a layer-window (e037: 1.25-1.72 ms); prose/rep `CPU` + `jobs` a window |
  | r3-e052-mix-c16400-zcp7 | mixed profile, `--expert-cache 16400` | e048; r3-base-1..3 (mixed at 19,112: review 31.49 at 99.7% hits) | does the bigger cache give the mixed profile review's warm hits back while keeping its prose/rep coverage |
  | r3-e053-zcp7-adapt16 | `--adapt-every 16`, warm, 19,068 | e014 (adapt16 alone: 32.23 / 27.39 / 31.36), e036 | A6 on top of the PASS-class miss path |
  | r3-e054-c16400-zcp7-adapt16 | e048 + `--adapt-every 16` | e053, e048 | all placement levers together |
  How to judge (REVIEW class: texts will differ from f1/f2; slots differ on purpose):
  - Valid only if: no `pressure_abort`, no GPU errors, min free >= 6.5 GiB, and e048 / e049 / e051 report the
    same slot count. If e048 and e049 disagree on texts at equal slots, the bigger cache is not reproducible
    (memory at start moved the cap): look at the `expert cache` line and min free before anything else.
  - Review: a new review best needs both e048 and e049 above f2's 35.61 + spread on the median (rule 4) and
    e051's review host time below e037's. Then: one `--needles` run at the same settings, an owner-visible REVIEW
    entry (new gate baselines = e048 + e049; the cache size is placement, routing and math unchanged), and an
    empty commit `decode X tok/s: --expert-cache 16400 + ...` naming e048/e049/e051 and the needles run.
  - Prose / repetition: report against e036 (24.31 / 29.93) and e044. A gain counts if both e048 and e049 beat
    them by > 10% with review not lower than e044's median.
  - e050 vs e048: if 15,500 gives >= 80% of 16,400's gain, prefer 15,500 (2.2 GiB more margin over the floor).
  - e052: if review >= e048's and prose/rep > e048's, the mixed profile + 16,400 is the better placement base.
  - A6 (e053/e054): candidate only under iteration 4's rule (review >= ~35.5 on the median and on request 1,
    pr_mean clearly above the non-adaptive run at the same cache size). Read e039/e040 (lag 2, trace) first: if
    lag 2 fixes review's dip, the next A6 run is e054 + `STRATA_ADAPT_LAG=2`.
- **Ranked next steps (iteration 10+):**
  1. `./ar_collect.sh`; judge e038-e047 by iterations 6-8, then e048-e054 by the table above.
  2. If A8 wins: needles run at the winning size, REVIEW entry for the owner (new gate baselines, recommend
     `--expert-cache` N + `--pool-workers 7` + zero-copy for base-overrides.json), then stack B7 (`STRATA_SPEC_COST`,
     if e045-e047 pass) on top of it.
  3. **Code: B8 "prompt-informed refill" (`STRATA_PROMPT_REFILL=1`), design ready in research-ideas.md B8
     (iteration 9).** Every request already refills ~1,780 lent cache slots after prefill (generate.cpp
     `refill_issue` ~10198); B8 fills them with the prompt's most-routed non-resident experts (counted from
     prefill.cpp's host-side `ids_h` ~3033-3074) instead of their profile owners: same copy count, no blocking
     rounds, placement only (REVIEW class). Build it next iteration whatever A8 says: it targets the first request
     of each workload, which neither A8 nor A6 helps (e014 request 1: prose 21.1, rep 23.0 vs 27-35 later).
  4. Code, review: B2 (HC 2-phase down+up fusion) or B1a, as in iteration 8's list.

### iteration 10 (2026-11-03 21:38-21:55 PST by `date`): e038 + e039 collected; B8 PROMPT_REFILL built and queued
- **r3-e038-gusw-prof (`STRATA_GU_SWIGLU=1` + VERIFY_PROFILE + timing, 625b9ae0): texts 1.0 on all nine; review
  34.34 (profiler on).** Experts `hits gate/up+swiglu` by T: T1 6.29, T2 10.08, T3 13.57, **T4 17.24** (e008, the
  separate kernels: 6.4 / 10.0 / 13.3-14.0 / **17.0**). The fused kernel is bitwise (p014/p015, e035) but saves
  nothing. **GU_SWIGLU is closed** (no GY sweep: iteration 7's rule needed >= 0.3 ms at T4).
- **r3-e039-adapt16-lag2 (`--adapt-every 16` + `STRATA_ADAPT_LAG=2`, warm, 625b9ae0, 19,068 slots): REVIEW class
  (texts change by placement), no GPU errors, no `pressure_abort`.**
  | workload | per request (tok/s, decode hits) | median | e014 (lag 1) |
  | --- | --- | --- | --- |
  | review | 35.0 99.9% / 33.9 99.8% / 36.1 99.9% | **34.96** | 32.23 (24.0 / 32.2 / 36.6) |
  | prose | 23.2 93.3% / 28.7 98.8% / 29.5 99.4% | **28.73** | 27.39 |
  | repetition | 28.2 91.3% / 40.4 97.9% / 43.1 99.1% | **40.44** | 31.36 |
  Texts vs f1/f2: review 0.675 / 0.132 / 0.041, prose 0.0185, repetition 1.0. pr_mean 34.59 (base ~16.5, e036's
  PASS-class zc + pool7 27.12). **Lag 2 fixes the review dip**: the copies land one window later, so no window
  waits for them; every review request is inside the base's range (f1/f2 per request 34.3-36.5). It meets
  iteration 4's A6 rule (review >= 34.9 on the median, pr_mean >= ~27, no errors); review request 1's text now
  changes too (0.675), so the "same-text request 1" check cannot be made: its 33.89 vs the base's 34.0-34.6 is
  inside the spread. Repetition's last request runs 43.1 tok/s, faster than review. Still slow: each workload's
  first request (prose 23.2, rep 28.2 at 91-93% hits), which is what B8 targets.
- Item: **B8 "prompt-informed refill" (ranked step 3), commit 7aa743b5, PENDING, opt-in `STRATA_PROMPT_REFILL=1`.**
  - Count: `Prefill::set_route_counts(int32_t*)` (prefill.hpp); in `run_impl`'s host-group branch, right after the
    per-expert token count `m.cnt` (prefill.cpp ~3120, the branch the bench takes: no `fused int8` line in f2's
    log), each layer adds `m.cnt[e]` to `counts[l * n_expert + e]`.
  - Choose (generate.cpp, `prompt_remap`, called at the top of `refill_issue`): candidates = pairs with
    `host_res < 0`, not one of the loan's owners, routed >= 2 prompt tokens, sorted by count (ties: lower index).
    Victims = the lent entries sorted by their owner's count (least first). Each candidate takes the least-routed
    remaining owner's slot whose room (`slot_offset(s+1) - slot_offset(s)`, the kvg fit check) holds its blob, if
    its count >= that owner's + 2; then `refill_issue` copies `p.lent`'s (now new) pairs into their slots and sets
    `host_res` as before. Displaced owners stay `kNotResident`. The next request lends the same slots
    (`host_res >= first`) and chooses again; counts reset after each remap. Cross-layer moves are fine: slots are
    addressed through the slot-offset table (`drive.d.cache_slot_off`, `vh.slot_off`), and kvg already moves
    experts across layers with the same fit check. Enabled only with one participant, no stages, no peer, no
    remote experts. Startup line `STRATA_PROMPT_REFILL=1: the lent slots refill ...`; per refill
    `prompt refill: N of M lent slots took prompt experts (R routed tokens counted, C candidates, counts hi..lo)`.
  - Default path: only `if (route_counts_ != nullptr)` and `if (!prompt_counts.empty())` added. No switch-off run
    gated against f1/f2 on this build (e060 is switch-off but adaptive, so its texts change anyway); add one if a
    later run looks odd.
- Queued at 7aa743b5 (~21:50, behind e054; all warm profile, `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1`):
  | exp | settings | compare with | decides |
  | --- | --- | --- | --- |
  | r3-e055-prefill-zcp7 | B8 | e036 (35.46 / 24.31 / 29.93), e044 | first check: both engine.log lines, N > 0 on the 4,096-token requests. Hits and speed per request on all three |
  | r3-e056-prefill-zcp7-rep | B8 (= e055) | e055 | `python3 compare.py runs/r3-e056-prefill-zcp7-rep/result.json runs/r3-e055-prefill-zcp7/result.json`: 1.0 on all nine = the refill is deterministic (prefill routing does not depend on placement). Rule-4 repeat |
  | r3-e057-prefill-zcp7-diag | B8 + timing + depth | e037 (zc, no pool7) and e051 | CPU experts a layer-window and host [jobs / CPU] per workload |
  | r3-e058-prefill-zcp7-adapt16 | B8 + adapt16 (lag 1) | e053 | B8 on top of A6 at lag 1 (queued before e039 said lag 2 wins: low value) |
  | r3-e059-prefill-zcp7-a16lag2 | B8 + adapt16 + lag 2 | e060 | **B8 on the full placement stack**: first-request prose/rep speed (e039: 23.2 / 28.2) and medians |
  | r3-e060-zcp7-a16lag2-needles | adapt16 + lag 2, B8 off, `--needles` | e039, e053 | **the A6 candidate with the PASS-class miss path**: review >= ~35.3, pr_mean >= e039's 34.6, needles 3/3 |
  How to judge (all REVIEW class: texts will differ from f1/f2):
  - B8 alone is a candidate if e055 and e056 agree 1.0 on all nine, both beat e036 by > 10% on prose or
    repetition, and review stays >= ~35.0 on both medians. A review loss would mean the profile's coldest pairs
    (the lent slots' owners) matter more to review's decode than the prompt's picks: then try a larger margin
    (count >= owner + 8) before closing.
  - B8 on top of A6: e059 vs e060. Keep if the first prose and repetition requests run faster than e060's and the
    medians are not lower.
  - If e055 is `no_result` with a compile error in its build log (B8 was not compiled on the Mac: no include
    paths here), all six share the failure: fix 7aa743b5's error, commit, and re-queue e055-e060 under new ids
    (e060's settings do not need B8 and can re-run on any build).
  - e060: if review >= ~35.3 and pr_mean >= ~34.6 with needles 3/3, the recommended base for the owner becomes
    `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1` + `--adapt-every 16` + `STRATA_ADAPT_LAG=2` (REVIEW class:
    new gate baselines = e060 + a repeat, e.g. r3-e061; A6 is placement only). Commit nothing until the repeat.
- **Ranked next steps (iteration 11+):**
  1. `./ar_collect.sh`; judge e040 (iteration 6), e041-e044 (iteration 7), e045-e047 (iteration 8), e048-e054
     (iteration 9), e055-e060 (table above). Check exe_sha256 per source state.
  2. If e044 confirms zc + pool7: the empty commit `decode X tok/s: ...` (iteration 8 step 2).
  3. A6 stack: if e060 qualifies, queue its repeat (r3-e061, same overrides, no needles), then write the REVIEW
     entry for the owner in the top block. If A8 (e048-e054) also wins, the next stack run is A8's size +
     zc + pool7 + adapt16 + lag 2 (+ B8 if e059 helps).
  4. Code, review: B2 (HC 2-phase down+up fusion, plan-review item 6) or B1a (rows table at 5-8 columns): the
     review headline has not moved in round 3 (best PASS 35.61 = f2), and placement work does not move it.

### iteration 11 (2026-11-03 21:50-22:10 PST by `date`): e040 judged; B1c STRATA_IL_SPLIT built and queued
- `./ar_collect.sh` logged e040; e041 (cbe51765) running, 19 pending. **r3-e060's repeat (iteration 10 step 3)
  must take a new id (r3-e064 or later): r3-e061..e063 are this iteration's.**
- **r3-e040-adapt16-trace (`--adapt-every 16`, lag 1, + `STRATA_TRACE_ADAPT` + timing; 625b9ae0, exe 46732e1c,
  19,068 slots; no GPU errors, no `pressure_abort`): review 34.70 (34.70 / 34.02 / 34.88, timing on), prose 27.93
  (23.61 / 27.93 / 29.73), repetition 40.44 (28.44 / 40.44 / 42.63); hits 99.8 / 98.9 / 98.0%.** Texts vs f1/f2:
  review 0.675 / 0.132 / 0.041, prose 0.041 min, rep 1.0; vs e039 (lag 2): review 1.0 / 0.525 / 0.44, prose 0.020,
  rep 1.0 (REVIEW class, placement timing). No review dip at lag 1, so e014's 24.0 request was a stall, not a
  blocking round: lag 1 and lag 2 run the same speeds. Trace: review's rounds swap 0-22 experts (the first rounds
  0-1), so the tier costs review little.
- **Finding (e040 timing, repetition requests 2-3 at 98-99% hits): repetition is capped by `--spec 4`, not misses.**
  70 windows a request, 3.66 tokens a window; T4 windows 63-65 a request with 2.86-2.90 of 3 drafts accepted (96%),
  round 88-93 ms; per-layer host 10-20 ms (no zc/pool7 in e040: those take it to ~3-5). The next repetition lever is
  wider windows. But at today's prices every width is about equal: e004's review rounds by T are T4 87-89, T5 111,
  T6 125-135, **T7 159-161, T8 166-169**, so at 97% per-depth acceptance T8 gives ~7.2 tokens / 168 ms = 0.043
  tok/ms, T6 5.6 / 130 = 0.043, T4 3.86 / 88 = 0.044. So `STRATA_SPEC_COST` + `--spec 8` alone gains ~0 on
  repetition (e006 found the same on the mixed profile), and review's best width stays T4 at any price (E5/E4 ~1.11
  vs the 1.27 cost ratio; even at the 11.5 ms slope a 5th column needs 1.13).
- Where T7/T8 lose (code read): `native_mmvq_il_max_cols()` is 4 (6 with `STRATA_IL56=1`), so 7-8 column windows
  fall to native_mmvq's plain one-pass `native_mmvq_multi_kernel<F, 7/8>` (launch_multi, native_mmvq.cu:1366). From
  e004 (T6 -> T7 verify +25 to +35 ms with ~9.5 of non-dense per column) the dense part is ~62-70 ms at T7-T8 vs
  44.1 at T6 (IL56) and 25.3 at T4 (r2 e014). Two 4-column IL passes cost ~2 x 25.3 = ~51.
- Closed by reading (no runs): gate/up micro-work (rounds 1-2: not weight latency e039, not activation loads e040,
  not grid gathers e036; dense Q6_K instruction diet r1 e043 gave nothing; the kernels are bound in their bodies
  at their occupancy); B2 HC fusion (96 HC instances x 1 fewer launch at ~2.5-4 us = 0.24-0.4 ms a window, ~0.5%,
  for an L item with a grid barrier); `STRATA_VRAM_GY` (r1 e061, r2: 8 is the optimum); `STRATA_DRAFT_VOCAB_TOP`
  (r1 swept 16384 / 32768 / 40960).
- **Code (commit 23a09959, PENDING, opt-in `STRATA_IL_SPLIT=1`, verify.cpp only, +44 lines)**: in record_window's
  dense `mm` lambda and the head, when the window has more columns than the IL kernels take (n > max cols, n <= 8)
  and the type is IL at 4 columns for that n_out (`native_mmvq_il_supported(type, 4, n_out)`, the base's
  `STRATA_MMVQ_IL_ROWS` included), `il_split_mm` interleaves columns 0-3 into xil_ and columns 4..n-1 into xil_ +
  `native_q8_1_il_bytes(max_in, 4)`, then runs `native_mmvq_il` at 4 columns and at n - 4 columns (native_mmvq at 1
  column, and native_mmvq_il falls back to native_mmvq where its rows table says 0), writing y columns 4.. at out +
  4 n_out. xil_ grows to `native_q8_1_il_bytes(max_in, 8)` (= two 4-column copies) when the switch is on. The
  existing `il_ready` flag (reset wherever xq_ is rewritten) covers both copies: a window's n is fixed, so split
  and plain IL never mix in one window. Bitwise argument: every kernel used gives a column the single-column dot
  (native_mmvq_il is bitwise native_mmvq per the header and mmvq_il_parity; native_mmvq's columns do not depend on
  NC: e004's spec 8 texts equal spec 4's on all nine). Startup line: `strata verify: STRATA_IL_SPLIT=1: windows of
  7-8 columns run the interleaved dense GEMVs and the head as two passes`. Not compiled on the Mac.
- Expected: T7 verify ~130-135, T8 ~138-142 (e004: 144.7-149.1 / 154.5-157.4); repetition at T8 ~7.2 tokens /
  ~150 ms round = 0.048 tok/ms vs T4's 0.044 (~+9%) once windows go wide; review ~0 (T4 stays its best width).
- Queued at 23a09959 (22:03, behind e060):
  | exp | settings (warm profile) | compare with | decides |
  | --- | --- | --- | --- |
  | r3-e061-ilsplit-spec8 | `--spec 8` + `STRATA_IL56=1` + split + timing + depth (= e004's overrides + the switch) | e004 (30.92; T7 144.7-149.1, T8 154.5-157.4 verify) | **PASS gate: texts 1.0 on all nine vs f1/f2** (a change = a column-offset slip in `il_split_mm`: check xq_b / out_b / the second copy's offset); T7 and T8 verify ms by window size; review speed vs e004 (it stays below f1/f2: spec 8 under the static gate) |
  | r3-e062-ilsplit-cost8-zcp7 | `--spec 8` + IL56 + split + `STRATA_SPEC_COST=1` + table `52.5,63.5,74.5,86.7,111,127,145,152` + zc + pool7, no timing | e044 / e036 (zc + pool7, spec 4), e047 (SPEC_COST + zc + pool7, spec 4) | PASS gate vs f1/f2 (window choice only). Review headline candidate only if > f2's 35.61 + spread and >= e044's median; prose/rep vs e036/e044 |
  | r3-e063-ilsplit-cost8-a16lag2 | e062 + `--adapt-every 16` + `STRATA_ADAPT_LAG=2` + timing + depth | e060 (zc + pool7 + adapt16 + lag 2 at spec 4), e039 | REVIEW class (placement). Repetition median and per request vs e060; repetition's T5-T8 windows (count, accepted, round ms) in `by window size`; review >= ~34.9 |
  Keep rule: e061 texts 1.0 and T8 verify >= 8 ms below e004's. Then: if e062 or e063 gains (e062 review above the
  bar with texts 1.0; or e063 repetition >= 10% above e060 with review held), repeat it without timing + `--needles`,
  commit `decode X: ...` (switch stays opt-in). Kill: texts change in e061 (revert 23a09959's call sites), or T8
  verify within 3 ms of e004's (the split does not pay: then T7-T8's cost is not the plain kernel; read e061's
  `STRATA_VERIFY_PROFILE`-free timing first, and a profile run would be the next step). If e061 passes and
  e062/e063 do not gain, the split stays as an opt-in for later wide-window work (B5 copy mode).
- If SPEC_COST is broken (e045-e047 text changes or no startup line), e062/e063 are invalid; e061 stands alone.
- e061-e063 went in at 22:03, two minutes before the owner's queue cap (12 pending); 22 jobs sit ahead of them.
  Per the cap note, e062/e063 are the "variants": if a later iteration needs queue room, e061 is the one that
  decides the split.
- **Ranked next steps (iteration 12+):**
  1. `./ar_collect.sh`; judge e041-e060 by iterations 7-10 (exe_sha256 per state), then e061-e063 by the table above.
  2. If e044 confirms zc + pool7: the empty commit `decode X tok/s: ...` (iteration 8 step 2). If e060 qualifies:
     its repeat as **r3-e064** (iteration 10's rule; e061 is taken).
  3. If the split pays on T7-T8: T5-T6 are next. IL56's CP-8 kernels cost 38.1 / 44.1 ms dense (r2 e014) vs a
     T4 + 1-2 column split at ~44.5 / ~45.9, so the split loses there; the lever is IL56's own 5-6 column kernel
     (r2: occupancy 8 -> 5 blocks at 91-122 registers). Try `STRATA_MMVQ_IL_ROWS` rows 2 at 5-6 columns for every
     type (r2 e016: Q6_K only, -2.6 to -4.7 ms of T5 verify), env only, with e061's overrides.
  4. Repetition wide windows also need the drafter: at T8 the MTP chain runs 7 steps (~2 ms each); B5 copy mode
     (lookup drafts, no chain cost) is the structural step after the split.
  5. Review headline: N6 (fold the GDN commit into the next verify, r2 notes iteration 5: ~0.8-1.2 ms a window)
     after e041/e042 say how much of the commit COMMIT_BATCH already removed.

### iteration 12 (2026-11-03 22:06-22:25 PST by `date`): queue full; B7b STRATA_SPEC_STALE built, committed, not queued
- `./ar_collect.sh` at 22:06 and 22:16: nothing new (r3-e041-cb still running, 22 pending, over the 12 cap).
- **Finding (r3-e040 engine.log, `by window size` + `suffix drafts` per request): repetition's wide lookup windows
  are priced out by request 1 for good.** Repetition request 1 (91.4% hits): T6 26 windows at 5.00 accepted, round
  195.66 ms; T4 19 at 136.26; suffix drafts 189 of 189 accepted. Requests 2-3 (98.0 / 99.2% hits): suffix drafts
  183 of 183 and 183 of 183 accepted, **yet every window is T4** (63 / 65 windows, 2.86-2.90 accepted, round 88-93).
  Code (draft_policy.cpp): `choose()` prices each lookup width with its own cost EMA (alpha 0.1); a width that is not
  chosen is never measured, and the only way back is the #1252 stale probe after **300 rounds** (~4 workload requests),
  which then moves the price only 10% of the way (195 -> ~189). So T6 stays at its cache-cold price for the whole
  process. The same holds for SPEC_COST's MTP chain (keep_draft probes only widths with < 3 rounds): **e063's
  repetition requests 2-3 will understate wide windows for this reason, not because the split failed.** Read its
  `by window size` per request: T7/T8 used in request 1 and absent in 2-3 = this bug.
- What a fresh price is worth (same tokens per ms arithmetic as iteration 11, repetition at ~100% acceptance, T4
  3.88 tokens / ~90 ms = 0.043 tok/ms): plain T6 (no IL56) ~1.58 x T4's GPU time (e008 129.6 vs 82.1) = ~139 ms,
  6 / 139 = 0.043: **no gain, and a correct policy keeps T4**; T6 with `STRATA_IL56=1` (e004 rounds 125-135) =
  0.046: **+4-6% on repetition's warm requests**; T8 with the split (iteration 11's estimate ~150 ms) = 0.053: +20%.
  So this item is an enabler for the wide-window stack, and IL56 belongs in every run that tests it.
- **Code (commit 2313e235, PENDING, opt-in `STRATA_SPEC_STALE=N`, 46 lines in 4 files)**: `DraftPolicy::set_stale(N)`
  (draft_policy.hpp) replaces the 300-round threshold with N and sets `stale_reset_`; `add_cost` then gives a round
  of a stale width EMA weight 1 (its price = that round; the robust 2x clamp still applies first); `keep_draft` (the
  SPEC_COST chain) also probes stale widths (`cost_n_ < kProbes || stale`, both of its probe sites). generate.cpp
  reads the env at both DraftPolicy sites (serve loop: startup line `strata serve: STRATA_SPEC_STALE=32: a window
  width unmeasured for that many rounds is tried again and re-priced by that round`; the one-shot loop: silent).
  Switch off: `stale_rounds_` 300 and no reprice = the old code path exactly. draft_policy_test gains one case
  (default: a slow-stretch T6 stays out 80 rounds; set_stale(32): retried at round 2, then taken in the 77 rounds
  after); traced by hand, not compiled (no include paths on the Mac; build.sh builds no tests).
  Caveats: a stale retry that lands on a stall (a 300 ms PLE window) prices the width high again until the next
  retry N rounds later (self-healing); seeded SPEC_COST_TABLE widths (last_ = 0) count as stale after N rounds and are
  probed once each, which costs a few wide probes per N rounds at spec 8 (~1% at N = 32).
- Override files written (all warm profile, `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1`), to queue when the cap
  allows (top block item 7):
  | exp | settings | compare with | decides |
  | --- | --- | --- | --- |
  | r3-e065-stale32-zcp7 | STALE=32 + `STRATA_IL56=1`, no adaptive tier, no timing | f1/f2 (gate), e044 / e036 | **PASS gate: texts 1.0 on all nine** (window choice and IL56 are both bitwise: e004). Review >= e044's median (lookups fire in ~2% of review windows: expect equal). Repetition here is miss-bound (no A6), so a small gain at most |
  | r3-e066-stale32-il56-a16lag2 | e060's settings + IL56 + STALE=32 + timing + depth | e060 (and e039 / e040) | REVIEW class (A6). Repetition requests 2-3: T6 lookup windows present in `by window size` (e040: none), their round ms, and the repetition median vs e060's |
  | r3-e067-stale32-cost8-a16lag2 | e063's overrides + STALE=32 | e063 | REVIEW class. Repetition requests 2-3: T7/T8 windows present (vs e063), tokens per ms per request; review not lower than e063's |
  Keep: e065 texts 1.0 on all nine, and e066 or e067 repetition median >= 5% above its comparator with review held
  (within the baselines' spread of its comparator). Then repeat + `--needles` and commit `decode X: ...` (switch stays
  opt-in). Kill: texts change in e065 (a window-dependent result: then e002-e004's "texts do not depend on the
  window" is wrong for lookup windows; check which workload) or no wide windows in requests 2-3 of e066/e067 (the
  retry did not fire: check the startup line and that `stale()` counts rounds as expected).
- **Ranked next steps (iteration 13+):**
  1. `./ar_collect.sh`; judge e041-e063 by iterations 7-11 (exe_sha256 per state). e063: read its repetition
     requests 2-3 with the stale-price bug above in mind.
  2. As soon as `ar_queue.sh` accepts: e067, e066, e065 (top block item 7). The e060 repeat as r3-e064 if e060 qualifies.
  3. Iteration 11's items 3-5 unchanged (IL rows at 5-6 columns env-only; B5 copy mode; N6).
  4. The 12-job cap means about one source state an hour: prefer settings runs on states already queued (af839e5b,
     7aa743b5, 23a09959, 2313e235 all contain every earlier switch, since each is HEAD at its time: 2313e235 alone
     covers COMMIT_BATCH, SPEC_COST, PROMPT_REFILL, IL_SPLIT and SPEC_STALE).

### iteration 13 (2026-11-03 22:17-22:30 PST by `date`): queue full; B5 copy mode built, committed, not queued
- `./ar_collect.sh` at 22:17 and 22:23: nothing new. **r3-e041-cb has been "running" since ~21:48** (e040's row is
  21:48:32): its build recompiles verify.cpp + verify_kernels.cu + native_qsa_indexer.cu. If it is still running at
  ~22:45, the build or the bench may be stuck: the owner should look at the Jetson's runner.log (agents have no ssh).
- **Measured basis (r3-e040 engine.log, `draft round to draft 0` lines):** repetition request 3 = 70 windows at 85.79
  ms, draft 7.18 ms a window = the round to draft 0 (T4 3.43 ms) + **129 chain steps / 70 windows = 1.84 steps x
  2.13 ms = 3.9 ms a window**, though 183 of 183 suffix drafts were accepted (the copy, not the chain, filled every
  window). Request 2: 127 steps / 70 windows x 2.09 = 3.8 ms of 90.4. Prose and review fire 1-2 suffix windows a
  request, so copy mode does not touch them.
- **Code (commit 96a17911, PENDING, opt-in `STRATA_COPY_MATCH=M`, 34 lines in mtp.hpp, mtp.cpp, generate.cpp):**
  in the serve loop, after the commit and before `mtp.draft`, `sfx.propose(S - 1, sbuf)` is run on the committed
  text (sfx already holds this window's tokens; the next window's own propose returns the same thing). If k >= S_mtp
  - 1, `last_match() >= M` and `policy.lookup_rate(match) >= 0.85` (choose()'s probe bar, so text where long
  matches stop holding turns the mode off by itself), `mtp.set_copy_gate(sbuf[0])`. In `MtpDrafter::draft`'s
  stepwise path (min_p > 0, the base's 0.5), the chain loop stops after draft 0 when draft 0 equals the gate (the
  gate is read and cleared at entry, so it covers one call). The next window then computes T <= 2 from dprob
  (draft()'s zero-filled tail) and the existing `policy.choose(T, k, match)` prices the copy against that 2-row MTP
  window, which the copy wins at q >= 0.85. Stopping after draft 0 is what min-p already does for a low-probability
  draft: the round still catches the drafter's K/V up for the accepted rows, and chain cells are rewritten before
  any read. Lines: startup `strata serve: STRATA_COPY_MATCH=12: ...`; per request `strata serve: copy mode: N
  windows drafted without the MTP chain, K of them took the copy`. Switch off: copy_match 0, no propose, gate -1,
  `copy_stop` false = the old loop. No unit test (MtpDrafter needs the GPU); the served text gate is the check.
- Expected: repetition at A6 warm hits (requests 2-3) -3.9 ms of ~86-90 ms a window = **~+4.5-5%** at spec 4; at
  spec 8 (e070) the chain would run up to 6 steps (~12.5 ms of ~150): **~+8%**. Review and prose ~0. Text identical
  without A6 (window choice only; e002-e004: texts do not depend on the window). With A6 the windows change the
  round count, so the adaptive rounds land elsewhere and texts may change (REVIEW class, as for e066/e067).
- Override files (all warm profile, `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1` + `STRATA_IL56=1` +
  `STRATA_SPEC_STALE=32`, i.e. each is its iteration-12 partner + `STRATA_COPY_MATCH=12`):
  | exp | = partner + copy | compare with | decides |
  | --- | --- | --- | --- |
  | r3-e068-copy12-stale32-zcp7 | e065 + copy | f1/f2 (gate), e065 | **PASS gate: texts 1.0 on all nine.** Review >= e065 (copy fires on < 5 windows a review request). Repetition vs e065 (miss-bound without A6: small) |
  | r3-e069-copy12-stale32-a16lag2 | e066 + copy (timing + depth) | e066 | **Speed.** Repetition requests 2-3: `copy mode: N windows` near the window count, `chain N steps` per window down from ~1.8 to ~0, draft ms per window down ~3.9; repetition median >= 4% above e066's with review held |
  | r3-e070-copy12-stale32-cost8-a16lag2 | e067 + copy (spec 8, split, SPEC_COST) | e067 | Wide-window stack: repetition requests 2-3 tokens per ms vs e067 (expect ~+8%) |
  | r3-e071-copy12-il56rows-a16lag2 (optional) | e069 + `STRATA_MMVQ_IL_ROWS` Q6_K 2 rows a warp at 5-6 columns (r2 e016: T5 verify -2.6 to -4.7 ms) | e069 | T5/T6 verify ms in `by window size`. The override replaces the base's env string, so it repeats the base's 2-4 column rows |
  Keep: e068 texts 1.0 on all nine and e069 repetition >= 4% above e066 (or e070 >= 5% above e067) with review held.
  Then repeat the winner without timing + `--needles`, commit `decode X: ...` (switch stays opt-in), and recommend
  `STRATA_COPY_MATCH=12` + `STRATA_SPEC_STALE=32` for the owner's base. Kill: texts change in e068 (then window
  choice is not text-neutral for copies: compare which workload, and read whether a copy window's verify differs
  from an MTP window's at the same T); or `copy mode: 0 windows` on repetition (the gate never armed: check that
  `lookup_rate` of bucket >= 12 is >= 0.85 and that k >= S_mtp - 1; e040's copies were 3-5 drafts long, so k >= 3
  holds at spec 4).
- **Ranked next steps (iteration 14+):**
  1. `./ar_collect.sh`; judge e041-e063 by iterations 7-11 (exe_sha256 per state). If e041 never finished, see the
     first bullet above.
  2. When `ar_queue.sh` accepts: top block items 7-8 on HEAD 96a17911 (one build): e069, e068, e067, e066, e065,
     e070, e071. The e060 repeat as r3-e064 if e060 qualifies.
  3. If copy mode pays: B5's other half, windows longer than 8 (`kVerifyMaxT = 8`, verify_kernels.hpp:21) is
     multi-iteration (per-size graphs 20-35 MiB each); not before the split (e061) and copy (e069/e070) both pay.
  4. Review headline: still no lever above ~1% that is not closed (N6 0.4-0.8%, r2 iteration 7). Placement items
     (A6, A8, B8) and wide windows move prose/repetition only.

### iteration 14 (2026-11-03 22:24-22:45 PST by `date`): e041 judged; compile check; B11 MTP stream priority committed
- `./ar_collect.sh` at 22:24: e041 still running (21 pending, over the cap all iteration). At 22:28 it logged e041.
- **r3-e041-cb (`STRATA_COMMIT_BATCH=1`, cbe51765, exe d5177e48 = f1/f2's binary, 19,068 slots): PASS, texts 1.0
  on all nine; the startup line is there (`GDN commit batched (36 layers), QSA commit batched`).** Review **35.02**
  (34.09 / 35.69 / 35.02) vs f1 35.47 (34.33 / 36.24 / 35.47) and f2 35.61 (34.55 / 36.46 / 35.61): every request is
  0.2-0.8 below, on the same binary at similar memory (min free 11.75 vs 11.92 / 12.04). Prose 16.23 (f1/f2 18.4-18.6),
  rep 15.19 (16.4-16.6), both miss-bound and noisy. No gain; possibly a loss. Iteration 7's rule: e042's ms/window
  (vs e001) and e043 (switch off, same binary, same conditions) decide; kill if e042 shows no window-time drop.
  **Mechanism to look for in e042: `draft` ms a window above e001's 5.91-6.08**. The commit graph runs beside the
  draft round (set_commit_async), and three large launches (36 layers' blocks at once) would crowd the draft's
  kernels more than ~110 small ones. If so, the default per-layer commit also costs the draft something, which is
  what B11 below targets.
- **Compile check of the five never-compiled commits** (four read-only reviewer agents, one per commit; see the top
  block): no definite compile errors, no default-path change. So a `no_result` in e045-e063 is not expected from
  the code; if one happens, read its build.log first anyway.
- **B10 written up (research-ideas.md, read only, not coded):** QSA decode attention is 2.73 ms of an 80.7 ms T4
  review window (T1 0.88) and runs at ~37 GB/s: the kernel is latency-bound (66 blocks a column, ~4 waves at T4).
  <= ~2% on review, an L item that must keep each column's reduce and fold order; behind B11 in value per effort.
- **B11 code (commit 7bdb2db8, PENDING, opt-in `STRATA_MTP_PRIORITY=2`, mtp.cpp only, ~15 lines):** MtpDrafter::load
  already creates `cs_` at the highest stream priority, but only with the forcing graphs (`--pipeline-windows 2`,
  `force_on_`). The serial serve loop (the bench's) runs the draft at default priority, beside the verifier's async
  commit graph on the verifier's stream (`Verifier::commit`: `set_commit_async` is on for one GPU, generate.cpp:3389;
  the next window waits for the commit through stream order, the drafter reads only this window's final rows and its
  own K/V). `=2` creates `cs_` and the shared-expert branch `side_` at `prio_hi` in the serial loop too; the commit
  keeps the default, so the draft's blocks are dispatched first and the commit fills the gaps (host syncs between
  chain steps). Graph launches take their stream's priority (no `cudaGraphInstantiateFlagUseNodePriority` in the tree).
  Unset, 0, 1 or any other value = the old rule exactly. Startup line `strata mtp: STRATA_MTP_PRIORITY=2: the drafter's
  streams at priority N`. Texts: identical by construction (scheduling only).
- Expected: the commit is ~1.6 ms of GPU work a window, ~1.2 ms of it on the critical path (round 2); the draft is
  5.9-6.1 ms a review window (e037). If priority moves even half of the commit off the draft's path: -0.5 to -1 ms a
  window, review +0.7-1.3%. More if e042 shows the batched commit hurting the draft (then e073 may turn
  COMMIT_BATCH into a gain).
- Override files (all warm profile; not queued, top block item 9):
  | exp | settings | compare with | decides |
  | --- | --- | --- | --- |
  | r3-e072-prio-diag | `=2` + zc + timing + depth (= e037's overrides + the switch) | e037 per request (ms/window 74.34 / 73.86 / 74.19; draft 5.92 / 6.01 / 6.11; GPU-reach 61.2-61.8; T4 round 84.3-84.8) | **texts 1.0 on all nine vs f1/f2 (also = e037's texts, so the window mix should match e037's exactly: check the T histogram)**; `draft` ms and ms/window per request |
  | r3-e074-prio-zcp7 | `=2` + zc + pool7, no timing | e044 (zc + pool7, same settings minus the switch), f1/f2 | PASS gate; review median vs e044's and f2's 35.61 + spread |
  | r3-e073-prio-cb-diag | e072 + `STRATA_COMMIT_BATCH=1` | e072 (same build, same conditions), e042 | does priority turn the batched commit into a gain: ms/window below e072's |
  Keep: e072 texts 1.0 and ms/window >= 0.4 ms below e037's on at least 2 of 3 requests at an equal T histogram
  (draft ms down), and e074's review median >= e044's. Then repeat e074 + `--needles`, commit `decode X tok/s: ...`
  (switch stays opt-in), recommend `STRATA_MTP_PRIORITY=2` for the owner's base. Kill: ms/window within 0.15 ms of
  e037's (the commit does not delay the draft; then COMMIT_BATCH's loss, if e043 confirms it, has another cause), or
  any text change (impossible by construction: look for a different window mix, i.e. a timing-dependent policy:
  `DraftPolicy` prices windows by measured round time, so a faster draft can change window choice; texts still must
  not change, since e002-e004 showed texts do not depend on the window).
- **Ranked next steps (iteration 15+):**
  1. `./ar_collect.sh`; judge e042/e043 (iteration 7 rule + the draft-ms check above), then e044-e063 by iterations
     7-11 (exe_sha256 per state).
  2. When `ar_queue.sh` accepts (< 12 pending): HEAD 7bdb2db8's batch in the top block's order (item 9).
  3. If e044 confirms zc + pool7: the empty commit `decode X tok/s: ...` (iteration 8 step 2).
  4. Review: B11 result first; B10 (attention, L) only after a `STRATA_BW_PROBE=1` + isolation measurement.

### Wrap-up (orchestrator, 2026-11-04 01:10- PST): loop ended, results judged, branch cleaned
- **Loop end:** iterations 16-19 hit the 5-hour usage limit (`iter-016..019.log`: "You've hit your 5-hour limit ·
  resets 1:10am"); `ar_loop.sh` stopped at 00:03 PST after 4 failed iterations, ~3.5 h before its deadline. The queue
  drained every run queued before then (e041-e063). Never queued (queue cap, then the limit): e064-e074 overrides
  for SPEC_STALE (2313e235), COPY_MATCH (96a17911) and MTP_PRIORITY (7bdb2db8).
- **Results e041-e063** (median tok/s; texts vs f1/f2; f1/f2 = review 35.47/35.61, prose 18.43/18.58, rep 16.58/16.44):
  | exp | settings | review | prose | rep | texts | verdict |
  | --- | --- | ---: | ---: | ---: | --- | --- |
  | e041 / e042 / e043 | COMMIT_BATCH =1 / =1 + timing / off | 35.02 / 35.35 / 35.51 | 16.2-18.5 | 15.2-16.3 | 1.0 | no gain (kept, opt-in) |
  | e044 | zc + pool7 + needles | 35.77 | 25.41 | 30.89 | 1.0, needles 3/3 | confirms e036 |
  | **e045 / e046 / e047** | **SPEC_COST + table** / + timing / **+ zc + pool7** | **36.64 / 36.76 / 36.82** | 18.99 / 19.10 / **25.92** | 16.54 / 16.49 / **30.78** | 1.0 | **review +3.3%: new best** |
  | e048 / e049 / e050 / e051 | cache 16400 (21,365 slots) / repeat / 15500 (20,210) / + timing, all zc + pool7 | 33.79 / 33.83 / 35.89 / 32.40 | 26.3-28.1 | 32.5-36.8 | changed | REVIEW: review -5% at 16400 |
  | e052 | mixed profile + 16400 + zc + pool7 | 33.40 | 30.19 | 43.13 | changed | REVIEW |
  | e053 / e054 | zcp7 + adapt16 / + 16400 | 35.03 / 33.32 | 27.66 / 29.99 | 41.12 / 42.06 | changed | REVIEW |
  | e055-e059 | PROMPT_REFILL (7aa743b5) + zcp7 (+ adapt16, lag 2) | 32.21-34.56 | 26.3-29.5 | 33.9-42.5 | changed | gate fail: dropped |
  | e060 | zcp7 + adapt16 + lag 2 + needles | 34.96 | 29.54 | 41.79 | changed, needles 3/3 | REVIEW |
  | e061 | IL_SPLIT + spec 8 + IL56 + timing | 32.68 | 17.36 | 16.12 | 1.0 | T7 149->133, T8 157->142 ms verify |
  | e062 | IL_SPLIT + spec 8 + SPEC_COST to 8 rows + zcp7 | 36.21 | 25.23 | **32.61** | 1.0 | best identical-text repetition |
  | e063 | e062 + adapt16 + lag 2 | 35.97 | 28.68 | 43.35 | changed | REVIEW |
- **Branch cleanup** (raw history kept locally as `ar/decode-speed-r3-raw` at 7bdb2db8): `ar/decode-speed` =
  53b3a758 + the seven PASS commits with measured messages: 37ab8e34 MISS_OVERLAP (no gain; zero-copy needs its
  pages_cached), 9badaa6d MISS_ZEROCOPY, 0b7dbbaf GU_SWIGLU (bitwise, no gain), e12a797a (comment-only rebuild
  fix), cbd714c2 COMMIT_BATCH (no gain), 308fb3ef SPEC_COST, 8f6ecdcd IL_SPLIT (HEAD). Dropped: 7aa743b5
  PROMPT_REFILL (text changed), 2313e235 / 96a17911 / 7bdb2db8 (never measured). Check: HEAD's tree differs from
  23a09959 (the state e061-e063 measured) by exactly 7aa743b5's diff.
- **Verification queued at 8f6ecdcd (01:20):** e075 clean HEAD (every switch off: must equal f1/f2 texts and speed),
  e076/e077 the e047 config (+ needles), e078/e079 the e062 config (+ needles).
- **Verification at 8f6ecdcd (exe 69995077 for all five; texts 1.0 vs f1/f2 on all nine; 19,068 slots):**
  | exp | settings | review | prose | rep | needles |
  | --- | --- | ---: | ---: | ---: | --- |
  | e075 | clean HEAD, every switch off | 35.60 (34.42/36.41/35.60) | 18.60 | 16.31 | - |
  | e076 / e077 | e047 = SPEC_COST + table + zc + pool7 | 36.84 / **37.02** | 25.67 / 25.90 | 30.87 / 31.37 | e077 3/3 |
  | e078 / e079 | e062 = + IL_SPLIT + spec 8 + costs to 8 rows | 36.58 / 36.80 | 24.75 / 23.80 | 32.35 / **33.19** | e079 3/3 |
  e075 = f1/f2 in texts and speed: the default engine is unchanged. Best per workload: review and prose = the e047
  settings (three runs 36.82-37.02 / 25.67-25.92); repetition = the e062 settings (32.35-33.19, ~+5% over e047's,
  but ~-1% review and ~-5% prose). e079's prose request 1 stalled (7.68 tok/s; median 23.80).
- **Installed 02:15 PST (round 2's way):** `~/strata/engine-fast-r3/strata` (sha 69995077, copied from ar/build after
  e079), `strata-iq3_s-fast-r3.json` = r3-e077's measured config with exe/log/port 8080 (= the installed r2 config +
  `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1` + `STRATA_SPEC_COST=1` + `STRATA_SPEC_COST_TABLE=52.5,63.5,74.5,86.7`),
  `run-iq3_s.sh` -> r3, rollback `cp run-iq3_s-fast-r2.sh run-iq3_s.sh` (r1's kept too). Scripts: `~/strata/install_r3.sh`,
  `~/strata/verify_r3.sh`. **Verified through `run-iq3_s.sh` (02:15-02:23): review 36.98 (34.41/36.98/36.99), prose
  25.72, repetition 31.12, prefill 333.6 tok/s, TTFT 12.34 s, needles 3/3, texts 1.0 vs f1/f2 on all nine, min free
  11.96 GiB.** The server was not running before and is stopped again. The fast-build guide's make_fast_config.py now
  writes this config (args and env equal to the installed file).
- **Open lead (not run): the miss pool runs on logical processors 1-3 (host on 0) at every `--pool-workers` value**
  (engine.log: "7 pool workers on logical processors 1,2,3"), so pool7's gain came from 7 threads on 3 cores and 8 of
  12 cores never run misses. Spreading the pool over all cores is the next prose/repetition item.

### iteration C1 (2026-11-04 13:50-14:00 PST by `date`): item 1, the miss pool on all 12 cores (built, queued)
- **Code read, pool.cpp:459:** a worker whose index is past `worker_cores.size()` gets core -1 and is **not pinned**.
  So e076's pool 7 = workers 0-2 pinned to CPUs 1-3 + workers 3-6 floating over all 12 CPUs (CPU 0 included, where
  the host spins). The wrap-up's "7 threads on 3 cores" is not quite it: 3 pinned + 4 left to the scheduler. The
  engine.log line (generate.cpp:4711-4718) prints only the pinned ones.
- **Change (commit 9e32f657, `PENDING r3-e080`, default off): `STRATA_POOL_SIBLINGS=1`** reads
  `topology/thread_siblings_list` (its first number = the lowest CPU of the core) in place of `core_id`, so the
  existing `(package, core)` dedup sees 12 cores on the Orin: host on 0, workers pinned to 1..N. Missing file = -1 =
  no dedup (the old no-sysfs path). Six lines in `detect_cpu_topology_impl` (Linux branch); `planned_host_core()`
  still returns 0, so the host pin is unchanged.
- **Texts:** every phase task computes whole rows (pool.cpp:629-690: one thread per row range, `mtasks_` depends on
  the worker count, not on the CPU), so pinning cannot change text; pool 9/11 change the row partition, which pool
  3 -> 7 already did with texts 1.0.
- **Queued** (source bfc3a758+1 = 9e32f657's tree; e080 running at 13:57): r3-e080-sib-p7, r3-e081-sib-p11,
  r3-e082-sib-p9, each = e076's overrides + `STRATA_POOL_SIBLINGS=1` (+ the pool count). Judge as the top block says.
  Risk to watch at pool 11: all 12 CPUs spin (workers spin 20 ms before sleeping, pool.hpp:221), leaving no free core
  for the IO prefetch / CUDA / HTTP threads; a review drop with prose up would mean pool 9 is the setting.
- **Next (ranked):** (1) collect e080-e082; repeat the best with `--needles`; (2) item 2: re-apply SPEC_STALE
  (raw 2313e235) and COPY_MATCH (raw 96a17911) on HEAD, one build, overrides = the best pool setting + each switch;
  (3) MTP_PRIORITY (7bdb2db8); (4) the 5th/7th column kernels.

### iteration C2 (2026-11-04 13:58-14:10 PST by `date`): items 2+3 re-applied in one build, queued
- At start: e080 running, e081/e082 pending (nothing to collect). The best pool setting is not known yet, so the new
  runs use e076's settings (pool 7 without SIBLINGS): each compares cleanly with e076/e077.
- `git cherry-pick` is not an allowed action, so the three raw commits were re-applied by hand with the editor
  (diffs read with `git show`): **commit 8ae45a4a** on top of 9e32f657, 6 files, +94/-11 (raw: +97/-12; the
  same hunks). STRATA_SPEC_STALE: draft_policy.{hpp,cpp} + the test case + two env reads in generate.cpp.
  STRATA_COPY_MATCH: mtp.{hpp,cpp} set_copy_gate + the serve loop's gate before `mtp.draft()` + one per-request
  line. STRATA_MTP_PRIORITY=2: mtp.cpp stream creation.
- **Checked by reading before queuing** (the raw commits were never compiled): the serve loop's `sbuf`,
  `req_spec_min_p`, `S_mtp`, `copy_match` are all in scope at the draft site (generate.cpp ~11708); `sfx.append` of
  the commit runs before it (~11697), so the gate's `propose` sees the committed text. A chain cut by the copy gate
  cannot widen the next window from stale probabilities: `draft()` zeroes `probs[n..]` (mtp.cpp:1618), and with
  SPEC_COST the rule has only seen idx 0, so `chain_rows` <= 2.
- **Queued** (source 8ae45a4a+0, 14:01): r3-e083-stale32, r3-e084-copy12, r3-e085-prio2, behind e081/e082. Judge as
  the top block's C2 PENDING says.
- **r3-e080-sib-p7 collected (14:03): SIBLINGS works but pinning 7 workers to CPUs 1-7 is slower everywhere.**
  exe 24cd29e7 (new, as expected), engine.log `7 pool workers on logical processors 1,2,3,4,5,6,7, the host thread
  on 0`; texts 1.0 on all nine, 19,068 slots. Review **36.10** (34.03/36.76/36.10) vs e076/e077 36.84/37.02;
  prose **22.55** (24.25/22.55/14.11; request 3 a stall) vs 25.67/25.90; repetition **28.47** (29.32/27.41/28.47:
  every request below e076's 30.86-30.95); prefill 334.6 vs 340-345. So e076's 3 pinned (cluster 0) + 4 floating
  workers beat 7 pinned over clusters 0-1. Earlier unpinned pool-count runs agree that more pool threads is not
  free: pool 11 (e009/e012, 3 pinned + 8 floating) ran review 34.45-34.73 vs pool 7's 35.05-35.11. Guesses (not
  tested): a pinned worker on another cluster pays cross-cluster coherence on the shared task counters that the host
  spins on, or it blocks the scheduler from moving it off a busy core (IO prefetch, CUDA driver threads). e081/e082
  decide whether any pinned count helps; one run, so rule 4 still wants the others before closing item 1.
- **Where repetition's window goes at zc + pool 7** (r3-e051 timing, cache 16400 but the same miss path): ~100 ms a
  window at 3.7 tokens = verify 91-95 (GPU-reach wait 50 + per-layer host 36-40 [jobs 7.7-7.9, **CPU 27-31**]) +
  draft 6.8-7.1. Prose: host 20.7 [jobs 4-6, CPU 14-16] of ~78 ms. The pool code (pool.cpp:613-711): tasks are
  claimed dynamically (`claim()`), `3 x threads` tasks a phase by default (`--pool-tasks 0`), and the host waits for
  *every* worker to park before and after each phase (`wait_parked`), 2 phases a layer (gate/up, down) x 48 layers.
  More threads did not help (pool 11: e009/e012; pinned 7: e080), so the per-phase tail/sync is a better suspect than
  core count. Never tested in any round: `--pool-tasks N` (row ranges only: each row is still computed whole by one
  thread, so texts stay identical), `STRATA_POOL_SPIN_US` (default 20 ms: workers spin through decode anyway),
  `--host-core last`, `--no-host-worker`. **Override files written, not queued (this iteration's budget went to the
  build): `overrides/r3-e086-ptasks64.json`, `overrides/r3-e087-ptasks128.json`** (= e076 + `--pool-tasks`).
- **r3-e081 / e082 collected (14:10 / 14:15), exe 24cd29e7, texts 1.0, 19,068 slots:**
  | exp | pinned CPUs | review | prose | repetition |
  | --- | --- | --- | --- | --- |
  | e076 / e077 | 1-3 + 4 floating | 36.84 / 37.02 | 25.67 / 25.90 | 30.87 / 31.37 |
  | e080 | 1-7 | 36.10 (34.03/36.76/36.10) | 22.55 | 28.47 (29.32/27.41/28.47) |
  | e081 | 1-11 (every core) | 35.00 (33.99/35.00/35.60) | 20.75 (23.53/20.75/19.79) | 24.78 (27.28/24.78/24.56) |
  | **e082** | **1-9** | **37.02** (34.51/37.21/37.02) | **26.19** (28.86/22.54/26.19) | **33.26** (33.34/33.26/32.81) |
  e081 fits the C1 risk: all 12 CPUs spin, nothing is left for the IO prefetch / CUDA / HTTP threads. e082 leaves
  CPUs 10-11 free and beats e076 on repetition by +7.7% (every request), prose +1-2% (noisy), review equal. e080's
  loss with 4 CPUs free is not explained (one run; a repeat would tell if it was noise). Queued **r3-e089** = e082 +
  `--needles` (14:17, behind e085) as rule 4's repeat. e086/e087 rewritten onto e082's settings (pool 9 + SIBLINGS).
- **r3-e083-stale32 collected (14:23): 8ae45a4a compiled** (exe bf6750eb, new; startup line `STRATA_SPEC_STALE=32:`
  present; pool line `1,2,3` as e076). Texts 1.0 on all nine, 19,068 slots. Review **36.73** (34.47/37.09/36.73),
  prose **23.17** (21.52/24.95/23.17), repetition **30.66** (30.45/30.71/30.66) vs e076 36.84 / 25.67 / 30.87
  (30.86-30.95). **No gain**: at e076's settings (no adaptive tier, SPEC_COST's robust costs) no width stays priced
  from a slow stretch, so retrying stale widths only adds probe rounds. Stays opt-in, not a new best.
- **r3-e084-copy12 / r3-e085-prio2 collected (14:30 / 14:36), exe bf6750eb, texts 1.0, 19,068 slots:**
  | exp | switch | review | prose | repetition |
  | --- | --- | --- | --- | --- |
  | e077 | (best, none) | 37.02 (34.54/37.06/37.02) | 25.90 | 31.37 (30.69/31.37/31.53) |
  | e084 | COPY_MATCH=12 | 36.93 (34.56/37.00/36.93) | 25.75 | 31.32 (31.11/31.69/31.32) |
  | e085 | MTP_PRIORITY=2 (priority -5) | 36.98 (34.64/37.13/36.98) | 25.85 | 30.68 (30.68/31.36/30.14) |
  COPY_MATCH works as designed: `copy mode: 0 windows` on every review and prose request, **55 / 59 / 59 windows a
  repetition request skipped the MTP chain and every one took the copy**, yet repetition moved +0.5-1.5% (spread).
  At spec 4 the chain is at most 3 steps (~2 ms each) of a ~100 ms window that the CPU misses dominate (CPU 27-31 ms,
  r3-e051), so the saving is ~2-4 ms at most. It should pay where the chain is long: spec 8 (7 steps) = e091 vs
  e090 (files written). MTP_PRIORITY: review equal per request; the commit graph is not contending with the draft
  at these settings. Empty commit d4d760c5 records all three.
- **Next (ranked):** (1) collect e089; queue e086/e087 (settings only, no rebuild if queued on the
  same source as e083: they then reuse its binary; check exe_sha256); (2) if e089 confirms: the empty commit + the
  owner recommendation (top block);
  **item 4 re-sized (C2, arithmetic only):** with SPEC_COST's table (52.5/63.5/74.5/86.7 ms for 1-4 rows) and review's
  depth acceptance (90/78/85%, then ~0.8), E4 = 1 + .9 + .70 + .60 = 3.20 tokens at 86.7 ms (36.9 tokens/s of window)
  and E5 = 3.68. A T5 at no cliff (+11.5 ms = 98.2) gives 37.5 (+1.5%); at today's cliff (+25 ms) 33.0 (SPEC_COST
  already avoids it). So the 5th-column kernel is worth <= ~1.5% on review; it pays on repetition's lookup windows.
  Cheapest first step there: `STRATA_MMVQ_IL_ROWS` 2 rows a warp at 5-6 columns for every type (env only; r2 e016:
  Q6_K alone took 2.6-4.7 ms off T5 verify), on e078's overrides (IL_SPLIT + spec 8 + costs to 8 rows). **Written,
  not queued: `overrides/r3-e088-il56rows-cost8.json`** (= e078 + rows 2 at 5-6 columns for Q6_K/IQ4_XS/Q4_K/Q5_K +
  timing; the env replaces the base's IL_ROWS string, so it repeats the base's Q6_K 2-4 column rows). Rows are
  bitwise (native_mmvq.cu:2599-2600), so texts should stay 1.0. Compare repetition and the T5/T6 round ms in
  `by window size` with e078/e079 (32.35/33.19). (3) a winning switch:
  repeat, then stack with the best pool setting; (4) the 5th/7th column kernels (PLAN.md) for review.

### iteration C3 (2026-11-04 14:38-15:30 PST by `date`): C2's five settings runs queued; NEON multi-token IQ3_S kernel built, queued
- At start: e089 running, nothing pending. Queued C2's files on d4d760c5+0 (clean tree): e086, e087, e090, e091,
  e088 (14:40). e086 and e089 collected at 14:50 (judged in the top block: pool 9 SIBLINGS is a trade-off, review
  ~-1%, prose ~+3%, repetition ~+5%; not a best).
- **Why the review headline is not this iteration's item** (e046 timing, review): a window is 74 ms = verify 68.6
  (GPU-reach wait 61.6, host 1.6) + draft 5.8 (draft 0 with catch-up 2.8-3.4 ms + 1.96 ms a chain step). The draft
  needs verify's hidden states and argmax, so it cannot start before verify ends; DF_BRANCH (side streams) was
  slower in round 1 (e072). What is left on review is the verify kernels (B1/B2, multi-iteration items) and ~1.5% at
  most from a 5th column (C2's arithmetic).
- **Finding (code read): on the Orin the CPU miss experts run ggml-cpu's one-token `vec_dot` per (row, token).**
  engine.log: `ARM CPU experts use ggml-cpu's native kernels`; native_expert.cpp `native_gu_rows`: the x86 builds have
  multi-token IQ kernels (iq512/iq256, "2.0-2.4x ggml-cpu at three tokens"), aarch64 falls through to
  `traits(gu_type)->vec_dot` in a `for r { for t }` loop, so each IQ3_S block (grid lookups, sign masks: the
  expensive part) is decoded once per token. Window groups hold 1.37 (prose) to 1.73 (repetition) tokens an expert
  (e046: 9.59 entries / 5.54 experts a layer-window on repetition).
- **Code (commit 9135446b, PENDING, opt-in `STRATA_IQ3S_NEON_MT=1|2`, native_expert.cpp only, +130 lines):**
  `iq3s_dot_mt` = ggml's NEON `ggml_vec_dot_iq3_s_q8_K` (local llama.cpp clone, arch/arm/quants.c:3929-4037) with
  the token loop moved inside the block loop: the 64-weight grid/sign decode runs once, then per token the same
  `vdotq_s32` pair, `vaddvq_s32 * scale` integer sums (exact in any order), and per 256-block `sumf += d * (float)
  (sumi1 + sumi2)` with d = fp16(x.d) * y.d. That float step is the only place the bits can differ from ggml's
  binary: mode 1 = `std::fma` (what GCC's default -ffp-contract=fast in gnu11 C should make of ggml's line), mode 2
  = rounded multiply, an empty asm barrier, then the add. The function sits in `#pragma GCC target("arch=armv8.2-a+
  dotprod")` (our TU has no -mcpu; ggml-cpu is built GGML_NATIVE) and runs only if `getauxval(AT_HWCAP)` has
  ASIMDDP. Dispatch in `native_gu_rows` before the ggml fallback: nt 2..MAXT, gu IQ3_S, act Q8_K; one token keeps
  ggml's dot. SiLU line copied from the fallback (`(g / (1.f + std::exp(-g))) * u`). Startup line from `native_fmt`.
  Not compiled on the Mac (no Linux aarch64 toolchain allowed here). Why mode 1 is the guess: ggml/CMakeLists.txt
  sets `CMAKE_C_STANDARD 11` and leaves C extensions on (our CMakeLists sets only `CMAKE_CXX_EXTENSIONS OFF`), so
  ggml-cpu compiles as -std=gnu11, where GCC contracts `a*b + c` by default (-ffp-contract=fast). Block layouts
  checked against llama.cpp ggml-common.h (block_iq3_s d/qs/qh/signs/scales, block_q8_K d/qs/bsums). IL rows for
  the Q5_K head are not a settings lever: round 1 settled them on the Orin (e035/e055).
- Queued (14:48, source 9135446b+0, behind e088): **r3-e092-neonmt1, r3-e093-neonmt2, r3-e094-sibp9-timing** (top
  block, item 2, says how to judge).
- **Next (ranked):** (1) collect e087/e090/e091/e088 and judge as the top block says; (2) collect e092-e094: which
  mode passes, its CPU ms vs e094; a keep gets a repeat + `--needles`; (3) if the gate/up kernel pays: the IQ4_NL
  down rows the same way (ggml_vec_dot_iq4_nl_q8_0, quants.c:4199: its float step `sumf += A*B*C + D*E*F` has more
  contraction choices, so expect 2-3 modes to try); (4) review: B1b (CP-4 + 5th-column IL kernel) or B2 (HC
  down+up fusion) as multi-iteration items.

### iteration C4 (2026-11-04 14:56-15:30 PST by `date`): replica-check diagnostic built; RAM-resident misses queued
- At start: e090 running; e091, e088, e092-e094 pending. Collected e090/e091 at 15:09 (top block: spec 8 config +
  pool 9 SIBLINGS = repetition 35.52, best identical-text; COPY_MATCH closed).
- **Review levers re-checked by reading, none above ~1.5% left that is not closed** (so the next agent does not redo
  it): device planning `STRATA_VERIFY_DEVICE_PLAN` (r1 e001/e017: the per-layer doorbell is off the critical path);
  QSA attention occupancy (r1 e077-e080: pre75 nc2 at 64 registers / 4 blocks a SM is the optimum, nc1/nc4 and
  `__launch_bounds__(256,4)` measured or spilled); draft vocab (r1 e019-e034: 40,960 rows); drafter chain step is
  GPU-bound at ~2 ms (r2 e020); head 152 GB/s at T1 (B12 note). Remaining: B1b 5th column (<= ~1.5%), N6 commit
  fold (~0.5-1%), B2 (~0.5%). The review headline needs one of those as a multi-iteration kernel item.
- **Finding (e090/e091 engine.log, per request): the file tier waits are large on prose and repetition.** `decode
  waited` = review 0.31-0.73 s (the 19-token warm-up 0.13), prose 1.69-2.04 s (of ~9.9-10.3 s decodes), repetition 2.19-2.72 s (of ~7.0-7.5 s),
  ~1,500 fetches a repetition request (~1.7 ms each = SSD blob reads); `page cache held 5.8 GB at the read, not
  10.5 GB` per request. **Caveat (e092, 15:28): it is not critical-path time.** Review's `decode waited` (0.30-0.65 s
  a request in e092) exceeds review's whole per-layer host time (1.2-2.4 ms x ~100 windows = 0.12-0.24 s), so the
  counter sums fetch waits that overlap the GPU (the io prefetch threads). Judge B14 by `jobs` / `CPU` ms and the
  medians, not by `decode waited`. The base never tried a RAM copy of the non-GPU experts (round 2 named `--resident-cpu-experts`
  as the lever when free RAM was ~7.7 GiB; it is ~12 GiB since the owner's 21:12 change). The engine has it:
  `--resident-budget-gib N` (generate.cpp:2230; built after the GPU cache, generate.cpp:6557-6640, so the 19,068
  slots do not move; "the bytes are the file's bytes and the placement is the same, so the answers are the plain
  mmap mode's"). bench.sh's run_control.py floor is 6 GiB MemAvailable, so N = 4 (min_avail ~11.9 -> ~7.9).
  Queued e096 (`--resident-experts`, likely `pressure_abort`, see top block) and e097 (`--resident-budget-gib 4`).
- **Code (commit bec4857c, PENDING r3-e095, opt-in `STRATA_MISS_REPLICA_CHECK=1`, native_expert.cpp only, +252
  lines, aarch64 Linux build only):** read-only replicas of every float step of the CPU miss path, counted against
  ggml's results in the running engine: `rep_q8k` (quantize_row_q8_K_ref: `nearest_int(iscale*x)` with the magic
  add fused or split; d, qs and bsums compared per row), `iq3s_dot_mt` at nt 1 (C3's kernel, modes 1/2), `rep_expf`
  (glibc e_expf.c: 32-entry table rebuilt from long-double exp2, aarch64 round/lround, cubic fused or split; vs the
  SiLU line's `std::exp(-g)`), `rc_q80` (arm quantize_row_q8_0: amax/127, 1/d, nearest-even of x*id, fp16 d), and
  `rep_iq4nl` (arm ggml_vec_dot_iq4_nl_q8_0's pair line in 3 forms). Hooks: after `from_float` in native_quant_act /
  native_quant_h, and inside the ggml fallback loops of native_gu_rows / native_down_rows (so with the NEON MT
  switch off). Counters are relaxed atomics; one stderr line at the first gate/up rows and then every 2^23 dots.
  Why: if every step has a 100% form, a GPU kernel can compute the misses with the CPU's exact bits (research-ideas
  B13), which turns the GPU-computes-misses idea (another project on the board: ~180 GB/s from mapped host memory) from REVIEW
  into PASS class. Not compiled on the Mac.
- **Code, not queued (commit 9343e5b7, HEAD): opt-in `STRATA_IQ4NL_NEON_MT=1|2|3`** = B12's down half: IQ4_NL down
  rows for 2-8 tokens with each block pair's nibble lookups once (`iq4nl_dot_mt`, native_down_rows before the ggml
  fallback; one token keeps ggml's dot). The pair line is `iq4nl_pair`, shared with e095's scalar replica, so
  mode = (the replica form e095 finds at 100%) + 1. Queue it only if e092/e093 show the gate/up kernel pays and the
  CPU part still matters; base = the passing IQ3S mode's override + this switch, A/B vs that run.
- Also queued: e098 (e090 repeat + needles, bec4857c) and e099 (commit 74590f2b, opt-in
  `STRATA_RESIDENT_RANK_PROFILE`: the RAM copy ranked by the mixed profile, GPU cache unchanged). Queue order at
  15:18: e092 (running), e093, e094 [9135446b], e095-e098 [bec4857c], e099 [74590f2b]: ~70 min of Jetson time.
- **Next (ranked):** (1) collect e092-e094 (C3's rules) and e095-e099 (top block); (2) if e097/e099 gain: the
  better one's repeat + needles, then a larger budget within the floor and the stack with e090's spec 8 config; (3) if e095
  shows 100% forms everywhere: B13 step 1 = the CUDA replica kernels behind a switch with a self-check against the
  CPU rows (one layer, logged), before any placement change; (4) review: B1b as a multi-iteration item.

### iteration C5 (2026-11-04 15:30- PST by `date`): B13 step 1 built (GPU computes misses with the CPU's rounding), queued
- At start: e093 running, e094-e099 pending (~60 min of Jetson time). Nothing to collect but e093 (top block: mode 2
  changes prose text, so ggml-cpu contracts its float steps into FMAs).
- **Why B13 now:** it is the largest identical-text lever measured (B13 brief: repetition ~+35-45%, prose
  ~+15-20% if every miss could go to the GPU), it does not depend on e094-e099 to be written, and the e095 result
  only picks forms, which are an env switch here, not a rebuild. Review items left are <= ~1.5% each (C4).
- **Code read that shaped it (so the next agent does not redo it):** the verify window already has a GPU share of
  the misses: expert_source.cpp:3412-3514 plans "kind 1" (PCIe) entries = the last `pcie_num/256` of a layer's misses
  whose blob is `pinned()` (in the RAM copy, expert_source.cpp:3027) up to `staging_cap` (16, or 8 per group at
  G 2), and verify.cpp post() runs them after the VRAM groups (`grouped(p_ptr2, p_start2, p_counts + 2,
  kPcieGroupRows, hit_out)`), into hit_out at `p_dst` rows, which `moe_hit_add` / STRATA_HIT_COMBINE treat exactly
  like VRAM rows (CPU rows are copied as-is, GPU rows enter as `0.0f + hit`; a down row is never -0.0 because ggml's
  `sumf` starts at +0.0, so the sign rule changes nothing). The base turns the share off (`STRATA_NO_PCIE=1`) and
  never had a RAM copy (so `pcie_layer()` was false anyway). `--pcie-mode` auto = 2 (a copy kernel stages each blob
  in device memory, then rebases the pointers). The fp32 x of the group is `mixed_ + tb * N` in post() (pre(l),
  post(l), pre(l+1) run in that order on one stream, verify.cpp:2487-2491), the same bits the host quantizes
  (`doorbell_publish` copies it to `m_x_`).
- **Code (commit b6f4b116, PENDING r3-e100):** `src/kernels/cuda/miss_exact.cu` (+330 lines, new; not under the
  --use_fast_math list, and every float op is an explicit `_rn` intrinsic anyway): three kernels per layer-group,
  each exiting at once when the plan has no PCIe group (graph-safe: the group count is read on the device):
  `mx_q8k_kernel` (one 256-block of one token a thread block: amax, first index of the maximum, iscale, magic-bias
  round fused/split, d = 1/iscale; static device scratch per group slot), `mx_gu_kernel` (32 rows of one expert a
  block, one warp per 4 rows; lane l decodes sub-blocks l, l+32, l+64 of the row: grid bytes with `__vsub4` sign
  flips, `__dp4a` against the Q8_K bytes, x scale; 8-lane xor sums give exact block sums; then every lane runs the
  10-block float accumulate in order; lane 0 does SiLU with a double-precision port of glibc's expf (table uploaded
  at verifier init from `std::exp2(long double)`, as rep_expf); then warp t quantizes entry t's 32 h values to one
  Q8_0 block), `mx_down_kernel` (one warp per down row, lane l < 20 owns IQ4_NL block l, exact integer dot, the
  pair line on even lanes, the 10 pair terms summed in order). Call site: verify.cpp post(), the PCIe launch;
  unsupported layout / > 8 tokens / > 80 entries / group > 1 falls back to grouped() with one warning line.
  Init: verify.cpp after the mapped staging (outside any capture).
- Known limit: the replica's scratch (Q8_K of x, Q8_0 of h) is static device memory per token group (`grp` 0/1),
  shared by every Verifier instance, so `--pipeline-windows 2` (two verifiers in flight) would race on it; the base
  does not pipeline windows. Give each verifier its own scratch before combining the two.
- Risks I could not check here: compile (no nvcc on the Mac); `cudaHostRegister` of the RAM copy with a device alias
  (else field 15 of `DONE` stays 0 and e100 equals e097); the staging copy kernel's cost per blob (~2.33 MB) on
  the critical path of the GPU stream; review losing ~1% to the extra launches.
- **Check mode (commit 478bbbac, run r3-e101):** `STRATA_MISS_GPU_EXACT=2`: expert_source.cpp's planner still
  publishes the PCIe groups but leaves their entries CPU entries (`kind -1`, after `counts[1]`), verify.cpp points
  the replica at a side buffer, and after the CPU rows land (`wait_flag_ge(m_flag_)`) `mx_compare_kernel` counts
  unequal floats; the last block copies the totals into mapped memory and the planner prints them to stderr
  (`miss_exact_report`). No device printf: the server's stdout carries its DONE protocol lines.
- e094 collected at 15:53 (top block: B12 closed). e095 was still running at 15:57; I left it to C6.
- Queued: r3-e100-gpuexact-resb4 and r3-e101-gpuexact-check (top blocks say how to judge). If e095's replica check
  finds forms other than 1110, C6 can queue `r3-e102-gpuexact-forms` = e100's overrides + `"STRATA_MISS_GPU_FORMS":
  "<e095's forms>"` at once (HEAD 478bbbac = e101's exe, no extra build). **Next (ranked):** (1) collect e094-e100 as the
  top blocks say; (2) if e100 passes and gains: repeat + needles, a 5 GiB budget if min_avail allows, then the
  mixed ranking (e099's switch) + e090's spec 8 config; (3) if e100's texts change: forms from e095, then a
  per-piece self-check; (4) if the share is slow (timing: GPU-reach wait grows): vector loads (16 B a lane) in
  mx_gu_kernel and `--pcie-mode direct` to skip the staging copy.

### iteration C6 (2026-11-04 15:57- PST by `date`): B13 code pre-reviewed (no defect found); e102/e103 queued
- At start: e095 running (since before 15:57), e096-e101 pending. Nothing finished to collect at 15:57 / 16:03 / 16:05.
- **Pre-review of miss_exact.cu + its call sites (b6f4b116 / 478bbbac), since nvcc is not on the Mac and e100/e101
  are the only builds of it.** No compile error or logic slip found; what was checked, so the next agent need not
  redo it: CUDA 13.2 (CONTEXT.md) = C++17 default, so the hex float literals compile (no other .cu uses them);
  `iq3s_grid` / `kvalues_iq4nl` come from ggml-common.h with DECL+IMPL_CUDA exactly as iq_kernels.cu does (same
  target `strata_kernels`, `third_party/ggml` include); block_iq3_s offsets (d 0, qs 2, qh 66, signs 74, scales
  106 = 110 B) and the decode (grid index bit k of qh[j] -> 256, sign nibble per 4 weights, the `0x00204081` byte-mask
  trick has no carries, `__vsub4(g^m, m)` = -g per byte, scale 2*nibble+1 low/high by sub-block parity) match
  dequantize_row_iq3_s and the NEON dot's scales32; the 8-lane xor sums cover exactly one block per lane octet
  (block i = round i>>2, lanes 8*(i&3)); per-block float step = `fp16(d)*y.d` then fma, as e092 proved; Q8_K
  (first max, -127/max, magic bias, d = 1/iscale; bsums unused by the IQ3_S dot); Q8_0 of h (amax/127, 1/d,
  nearest-even, fp16 RN); IQ4_NL pair line + in-order 10-pair sum from +0.0 (GCC's widening_mul fuses the first
  mult of `X*C + Y*F` = form 0, the default); glibc e_expf.c port (aarch64 TOINT_INTRINSICS: round = frinta,
  table bits, cubic) incl. the special cases. Index spaces: the planner's `P.tok = i / k` is group-relative and the
  replica's x is `mixed_ + tb * N`, so they agree; `P.dst = i` indexes hit_out / m_ymiss_ / the side buffer alike.
  Plumbing: `--resident-budget-gib` builds the complement with `cudaHostAlloc(Mapped|Portable)` +
  `cudaHostGetDevicePointer` (expert_source.cpp:2486-2501; the paced path registers a prefix), so `pinned()` /
  `device_alias()` / `pcie_layer()` are true for the copy and the PCIe share can reach it (C5's "field 15 stays 0"
  risk is unlikely; read it in e100's timing line anyway).
- Queued (no new build, 478bbbac = e101's exe): **e102** = e100 + mixed-profile ranking of the RAM copy, **e103** =
  e102 on e090's spec 8 config. Top block says how to judge (only if e100 passes). Not queued: a `--pcie-mode
  direct` variant (skips the staging copy kernel; the replica would read the mapped copy with byte loads, whose
  speed from host-mapped pages is unknown): queue it only if e100's timing shows the GPU share's wait growing.
- **Next (ranked):** (1) collect e095-e103 by the top blocks; (2) e100 passes: e102/e103 decide ranking + stack, then a
  clean repeat + needles of the best; (3) e100 texts change: e095's forms via `STRATA_MISS_GPU_FORMS` (same exe),
  and e101's first unequal float (1 ulp = a form, garbage = an index slip); (4) slow share: `--pcie-mode direct`,
  then 16-byte loads in mx_gu_kernel.
- Also read (C6, 16:07): `--pcie-frac` only sets the decode planner's `drive.d.pcie_num` (generate.cpp:7873/10454);
  the prompt path in `stream_all` mode computes every non-GPU expert on the GPU and uses `pinned()` only to DMA the
  blob instead of staging it (prefill.cpp:2305-2333); its CPU share needs `!stream_all` (prefill.cpp:3034). So the
  RAM copy and `--pcie-frac 1` should not move prompt arithmetic: if e097 (RAM copy alone) changes text, suspect
  prefill.cpp:3136's `pinned || !transient` candidate rule first, and do not judge e100's texts until that is known.

### iteration C7 (2026-11-04 16:08-16:25 PST by `date`): nothing to collect; B13 follow-ups written; review re-checked
- At start and at 16:15: e095 running (since ~15:53), e096-e103 pending. Nothing to collect. The queue runs slower
  than ~6 min a job (another project's GPU lock, see "The board is shared"), so e100-e103 may land after ~17:15.
- **Written, not queued (top block, C7): r3-e104 (`--pcie-mode direct`) and r3-e105 (`--resident-budget-gib 5`)**,
  both e100's overrides + one change, source 478bbbac (no rebuild). Queue only if e100 passes. Read for e104:
  expert_source.cpp:3500 gives the PCIe groups `device_alias()` pointers when `pcie_mode != 0`, verify.cpp:2365
  stages blobs only at pcie_mode 2, and `P.fetch` gets 0 fetches in direct mode, so miss_exact_grouped reads the RAM
  copy in place with the same exe. The kernel-side fix if direct turns out slow is written up in research-ideas.md
  B13 ("C7": shared-memory row staging behind `STRATA_MISS_GPU_STAGE=1`, same arithmetic). Not built on purpose:
  nothing measured says the share is slow, and a compile slip at HEAD would break every settings-only run queued
  on HEAD after it.
- **Review re-checked from e092's timing lines (so the next agent need not):** review windows are 74-77 ms =
  verify 68-71 (GPU-reach wait 61.7-64.4, host 1.2-2.4) + draft 5.8-6.4 (draft 0 after catch-up 2.8-3.4 ms + ~1.4
  chain steps at 2.0 ms) + commit/emit 0.05-0.08. GPU kernels are ~85% of the window; the draft is serial behind
  verify (it needs verify's hidden states). Nothing new under ~1.5% that is not already closed (C4's list stands).
- **The review stalls (`stage` ~302 ms a window, the same number in r2 and r3) are the PLE n-gram gather**:
  `stage` in the timing line is `ver.ms_host`, and verify.cpp:3147 / 4830 add `ss.ple.table->gather_batch(...)` to
  it. ple_reader.cpp has no fixed ~300 ms timeout (the worker blocks on the file port with timeout -1; the
  keep-alive, `STRATA_SSD_KEEPALIVE` default 100 ms, already keeps the SSD awake between rows), and the 28.8 GB table
  cannot be locked in RAM (`--ple-io ram`; ~12 GiB free). So the stall is the SSD itself being slow for a whole
  request (a guess: thermal throttling after each prompt streams ~11 GiB of non-GPU experts). If so, B14's RAM copy
  cuts each prompt's SSD reads by ~4 GiB: compare the stall count in e097-e105 vs e076-e094. No code change
  proposed. **Baseline (Grep over the 11 timed r3-e04x-e09x runs, 99 requests): 6 requests have `stage` >= 10 ms a
  window** (normal is 0.01-0.08): e094 review 302.6 / 15.8 and prose 16.0, e051 review 180.3 and prose 41.2, e057
  review 26.0. So ~6% of requests stall, review most often; one bench of 9 can hold 3 (e094).
- **Next (ranked):** (1) collect e095-e103 by the top blocks; (2) e100 passes: e100-best repeat + `--needles`, then
  e104/e105 (top block C7); (3) e100 texts change: e095's forms via `STRATA_MISS_GPU_FORMS` (same exe), e101's
  first unequal float; (4) direct slower than staged: build research-ideas B13 "C7" staging (one build, A/B on one exe).

### iteration C8 (2026-11-04 16:18- PST by `date`): nothing to collect; review levers sized against the per-T profile; B14 + spec 8 written
- At start (16:18) and 16:22: e095 still running (since ~15:53), e096-e103 pending. Nothing to collect. e095 is a new
  exe (bec4857c build) and its replica check adds scalar replicas beside every CPU-miss dot (prose/repetition windows
  are miss-bound, so expect that bench to run slower than ~6 min); add the other project's GPU-lock waits (up to 20 min a job).
- **Review: B1b (5th-column dense kernel) is worth ~0 on review, not <= 1.5% (arithmetic, so nobody builds it for
  review).** r2's per-T profile (r2 notes.md:153-171, e014): T4 -> T5 = +25.0 ms profiled, of which dense +12.8 (its
  T2-T4 slope is +2.0, so the cliff's excess is ~10.8) and waitCPU +2.4 (more unique experts); everything else grows
  at its normal ~+10.5. A perfect 5-column dense kernel therefore leaves T5 at ~+13-15 ms over T4. What a 5th column
  buys on review: P(drafts 1-4 accepted) x P(5th) = .9 x .78 x .85 x .8 = 0.48 tokens at ~27 ms a token (37 tok/s)
  = ~13 ms. Break-even at best; SPEC_COST already picks T5/T8 only in high-acceptance stretches. (C2's +1.5% assumed
  T5 = T4 + 11.5, below the profile's non-dense growth alone.) For repetition (all drafts accepted) the spec 8 config
  picks T8 = two 4-column passes (IL_SPLIT), so a 5-6 column kernel does not reach it either (e088: rows 2 at 5-6
  columns, no gain). **N6** (fold the GDN commit into the next verify) ~0.4-0.8% (r2 iteration 7) and **B2** (HC
  fusion) ~0.5% (C4) are both below what a 3-request median resolves (0.2 tok/s spread = 0.5%) and multi-iteration.
  Writing every per-position GDN state inside verify (llama.cpp's snapshot slots, engines-and-papers.md 1.4) is
  worse here: T x ~3 MiB of writes a GDN layer vs the replay's one read + one write, so it loses at T >= 3 on a
  bandwidth-bound board. **Conclusion: no review lever above the spread is left for this round; the headline stays
  r3-e077's 37.02.** The round's remaining Jetson time is best spent on B13/B14 (prose, repetition).
- **Written, NOT queued: B14 on e090's spec 8 config** (source = HEAD 478bbbac; both switches exist there, so no new
  build if queued on it): `overrides/r3-e106-resb4-cost8.json` = e090/e098's overrides + `--resident-budget-gib 4`
  (copy ranked by the warm profile, = e097's change); `overrides/r3-e107-resb4-mixrank-cost8.json` = e106 +
  `STRATA_RESIDENT_RANK_PROFILE=.../iq3_s-mixed-r3.bin` (= e099's change). No timing, so the medians compare with
  e090/e098 directly. **Queue only the one whose spec 4 twin won** (e106 if e097 beat e094/e082-class on
  prose/repetition with texts 1.0, e107 if e099 beat e097), and only if B13 did not already give the stack (e103
  covers B13 + B14 + spec 8; if e100 passes and gains, e106/e107 are just the A/B that separates B13's share from the
  copy alone, queue the matching one after e103 only if there is time). Gate: texts 1.0 on all nine, 19,068 slots,
  min_avail_gib > 6. Judge vs e090 (35.52 repetition, 26.16 prose) and e098: repetition or prose above its bar
  (repetition ~35.9 = e090 + spread) = repeat with `--needles`, then `decode X: ...` (settings only, empty commit).
  Command: `./ar_queue.sh r3-e106-resb4-cost8 "e090 spec 8 config + --resident-budget-gib 4" overrides/r3-e106-resb4-cost8.json`
  (or the e107 file, "... + mixed-ranked copy").
- No code change, no commit (nothing measured; the override files are lab files).
- **Next (ranked):** (1) collect e095-e103 by the top blocks; (2) e100 passes: its repeat without timing + `--needles`,
  then e104/e105 (C7); (3) e100 texts change: e095's forms via `STRATA_MISS_GPU_FORMS` (same exe), e101's first
  unequal float; (4) B13 fails but B14 (e097/e099) gains: e106 or e107; (5) review: nothing above the spread left.
- **C6's open question closed (code + e094's engine.log): the RAM copy cannot move the gated prompts' arithmetic.**
  The prompt CPU share is ON by default (log line `prefill: the CPU share is ON by default for prompt chunks below
  1024 tokens`), measured (`auto`, timing-dependent) and the only place `pinned()` changes the CPU's candidates
  (prefill/prefill.cpp:3136). But it needs `!stream_all` (prefill.cpp:2262/3034), and `stream_all` = ring > 8 and
  T >= stream_all_min() = 1024 (the default share caps it at 1024, prefill.cpp:189). Every gated prompt is `prompt
  4096 tokens` read as one chunk (`prompt chunk auto: 8192 tokens, a 96-slot ring`), so stream_all is true and the
  share never runs on them; only the 19-token warm-up prompts take it (not gated). So if e097/e099 change text, the
  cause is in decode, not the prompt path (with `STRATA_NO_PCIE=1` the decode misses stay CPU work reading the same
  bytes: suspect the copy's bytes, i.e. expert_source.cpp's complement build, first).

### iteration C9 (2026-11-04 16:24-16:40 PST by `date`): e095 collected (B13 forms proven = 1110); e108 queued; CUDA port re-reviewed
- At start: e095 finished (collected by `./ar_collect.sh`), e096 running, e097-e103 pending. At 16:32 still the same.
- **e095** (exe 108a5aecc594d274, source bec4857c+0): texts 1.0 on all nine, 19,068 slots; every replica piece has a
  100% bit-equal form and it is the default `1110` (numbers in the top block and research-ideas.md B13 "Step 0
  result"). Speed not judged (scalar replicas beside every miss): review 36.18, prose 16.32, repetition 15.71.
- **Queued r3-e108-gpuexact-resb4-needles** (source 478bbbac+0 = e101's exe, no build): e100's overrides without
  `STRATA_DECODE_TIMING` + `--needles`. Speculative on purpose: the queue (e096 + 8) runs to ~18:00, so a B13 win
  could not otherwise get rule 4's repeat inside the window. Judge rule in the top block (C9): only if e100 passed.
- **Second review of miss_exact.cu, now against the CPU replicas e095 proved (C6 reviewed it against ggml's
  sources):** no defect. Checked step by step: Q8_K (first-max via min index of `ax == amax`, `__fdiv_rn(-127, max)`,
  fused magic bias, `min(127, v)`, d = `__fdiv_rn(1, iscale)`); IQ3_S (qh bit k of byte j -> bit 8 of grid index k,
  sign byte 4j + k/2 nibble k&1 = ggml's mask1/mask2 bytes, `__vsub4(g^m, m)` = -g, scale = ggml's scales32 byte j>>1
  low/high nibble by j&1, integer sums exact (max ~15 M < 2^31), then per block in order `fma(fp16(d)*y.d,
  (float) sum, sumf)`); SiLU `__fmul_rn(__fdiv_rn(g, __fadd_rn(1, e)), u)` = native_expert.cpp:1025's expression;
  expf (glibc's -103.97..-103.28 `__math_may_uflowf` band returns 2^-149 where the port computes, but SiLU only sees
  it at g > 103, where 1 + e == 1 either way); Q8_0 of h (`vmaxvq` = fmaxf shuffles, d = amax/127, RNE of h*id, fp16
  RN); IQ4_NL (low nibbles = weights 0-15 against y bytes 0-15, high = 16-31, form 0 pair line, pairs summed in order
  from +0.0). Data: x is `xm = mixed_ + tb*N` (verify.cpp:1728), the buffer `doorbell_publish*` copies to the CPU's
  m_x_; PCIe-share rows go through `moe_hit_add` like every GPU row (only -0.0 -> +0.0, harmless). Half loads are
  aligned (row strides 1,100 / 360 B, down_off 1,408,000 even). So **if e100's texts change, read e101's first
  unequal float before suspecting the arithmetic**: a whole-row garbage value = bytes (staging / rebase pointers),
  a 1-ulp value = a step I misread.
- Also pre-reviewed the two never-compiled commits every e099+ build includes (74590f2b, 9343e5b7): no compile defect.
- Source snapshots are rsynced at queue time (jrun.sh `jqueue`), so new commits at HEAD do not touch queued jobs; only
  jobs queued after them build the new code.
- No code change, no commit.
- **Next (ranked):** (1) collect e096-e103 + e108 by the top blocks (e100/e101 decide B13; e097/e099 decide B14 and
  its ranking); (2) e100 + e108 pass and gain: commit `decode X: ...` (empty, evidence e100/e108, needles from
  e108), then e104/e105 (C7) if time; (3) e100 texts change: e101's first unequal float, then a fix under a new id;
  (4) B13 fails, B14 gains: e106 or e107 (C8); (5) review: no lever above the spread left (C8).

### iteration C10 (2026-11-04 16:34- PST by `date`): nothing to collect; B1's per-column half closed under the bitwise rule
- At start (16:34) and 16:40: e096 running (since ~16:24), e097-e103 + e108 pending. Nothing finished. No code change,
  nothing queued (the queue already reaches ~18:00; a new job would land after the window).
- **Why the dense per-column slope (+2.0 ms a column, r2 e014: 19.15 / 20.56 / 23.76 / 25.30 ms at T1-T4) cannot be cut
  by a bitwise kernel, so nobody builds B1's slope half (or a tensor-core GEMV) for review:**
  1. The pinned float expressions (native_mmvq.cu) round per integer group: Q6_K `sumf += d8[i] * float(dp4a * sc)` per
     **4 weights** (q6_q8_dot_impl, :644), Q4_K/Q5_K `sumf_d/m += d8[i] * float(dot * sc/m)` per **8 weights**
     (:539, :187), IQ4_XS `d * float(sumi)` per 32 (:1413). Dense bytes by type (round 1 e018, strata-ar-lab
     notes.md:244): Q6_K 1292 MiB (64%), Q5_K 327, Q4_K 187, IQ4_XS 159. A bitwise kernel must do, per column, one
     int multiply + conversion + FMA per group in the pinned order; that is the per-column work, and it does not depend
     on how the integer dot is formed.
  2. Tensor cores: int8 `mma.m16n8k16` sums 16 k-values; a 4- or 8-weight group uses 4/16 or 8/16 of it, and the C
     fragment (rows g/g+8, columns 2t/2t+1) must be re-mapped to the lane order of the pinned reduction (4 virtual
     warp sums, then the xor tree, which is a fixed bit-reversed binary tree over lanes). One dp4a already does a
     4-group. So no gain on K-quants; IQ4_XS (8% of dense) could gain <= ~0.15 ms a column. Closed.
  3. I2F: the Q6_K IL path already uses `exact_i2f_22` (`q6_q8_dot_impl<true>`, :641, "-0.4 ms a verify window");
     Q4_K/Q5_K's conversions were dropped by round 1 as < 0.1 ms each (strata-ar-lab notes.md:1088). Re-derived here:
     Q4_K + Q5_K are ~0.85 G weights at 0.25 conversions a weight a column, half Q6_K's count, so ~-0.2 ms a window
     by e043's ratio: below the 0.5% spread. Not worth a kernel build.
  4. Draft side: `STRATA_DRAFT_VOCAB_TOP=40960` is in the base (round 1: 16384 and 32768 lost), the drafter's experts
     are already a q8_0 file loaded as iq4_xs (`STRATA_MTP_EXPERTS_AS`). Nothing settings-only left there.
- **So review's last real lever is B1's fixed T1 part**: r2 e014's T1 dense row (19.15 ms) reads roughly 2.6 GB
  (round 1's 2,007 MiB of dense types + the 521 MB Q6_K head), ~137 GB/s vs ~180 streaming: ~4-5 ms a window above
  the bus floor (round 1 measured 83-100 GB/s on older kernels; re-measure per stage before sizing). Bitwise route: a load-time byte re-layout of the dense weights
  so each lane's chunks sit contiguous and come in 16-byte loads several blocks ahead (more bytes in flight; the
  lane-to-chunk map and the accumulation order stay the same, so the values are bitwise). Written up already as round
  2's research-ideas.md item 3(c) ("Marlin trick"); an L item for round 4, not startable inside this window.
- **Next (ranked, unchanged from C9):** (1) collect e096-e103 + e108 by the top blocks (e100/e101 decide B13; e097/e099
  decide B14 and its ranking); (2) e100 + e108 pass and gain: commit `decode X: ...` (empty, evidence e100/e108,
  needles from e108), then e104/e105 (C7) if time; (3) e100 texts change: e101's first unequal float, then a fix
  under a new id; (4) B13 fails, B14 gains: e106 or e107 (C8); (5) review: nothing above the spread this round.

### iteration C11 (2026-11-04 16:43- PST by `date`): nothing to collect; review's fixed cost sized by stage from e038 (round 4 brief B16)
- At start (16:43) and 16:47: e096 running (since ~16:24), e097-e103 + e108 pending. Nothing finished. No code change,
  nothing queued (the queue reaches ~18:00; no new source to measure).
- **Did what C10 asked before sizing B1's fixed part: read the per-stage table, with bytes, from r3-e038's profile
  (engine.log:61, review request 1, 101 windows) and the `native dense: types` line (engine.log:6).** At T1 (48.81 ms
  window): the big four dense GEMVs (GDN qkv / z, out-proj, QSA q: 1,939 MB) take 15.77 ms = **123 GB/s** (qkv 130,
  z 117, out 127, q >= 107); shared expert + quant 2.82 ms for 143 MB = **51 GB/s** (latency-bound launches); head 152
  GB/s; VRAM-hit gate/up+SwiGLU **107 GB/s**, down 121 GB/s (T4: ~119 / ~144). Ceiling ~172-180 GB/s.
- **Sized at 165 GB/s: dense -4.0 ms a window (~+5% review, 37.0 -> ~38.9), dense + expert gate/up ~+10-11%.** These
  are the only review levers above the 0.5% spread left, and both are byte re-layouts that keep every integer and
  every float step (bitwise by construction): Q6_K lane-major 4-block groups (16-byte loads, 4 a lane per 4 blocks
  vs ~28 16-bit/8-bit loads today; same 840 B a group, rides the existing `STRATA_Q6_PACKED` registry as a
  duplicate copy of 1.29 GiB, prefill untouched) and IQ3_S row planes for the expert slots (in place at fill time;
  the prefill expert kernels read the slots too, so harder). Cheapest first step, no layout change: the IL kernel's
  `m0` loop split into a guard-free main part with the 4 blocks' loads issued first (check spills). Design, table,
  code pointers and the bitwise argument (IL's acc[v] = the T1 kernel's warp-v partial, native_mmvq.cu:699-721 vs
  1509-1535): research-ideas.md B16. L item for round 4; not startable inside this window (nothing could be
  measured before 18:00).
- No code change, no commit.
- **Next (ranked, unchanged from C9/C10 for this round):** (1) collect e096-e103 + e108 by the top blocks (e100/e101
  decide B13; e097/e099 decide B14 and its ranking); (2) e100 + e108 pass and gain: commit `decode X: ...` (empty,
  evidence e100/e108, needles from e108), then e104/e105 (C7) if time; (3) e100 texts change: e101's first unequal
  float, then a fix under a new id; (4) B13 fails, B14 gains: e106 or e107 (C8); (5) review, round 4: B16 step 1
  (guard-free IL main loop), then the Q6_K lane-major copy.

### iteration C12 (2026-11-04 16:50- PST by `date`): e096/e097 = pressure_abort (copy costs 1.46x); B13 re-aimed at 2.5 GiB (e109, ar_run prio 0)
- At start: e096 finished (`pressure_abort`, min_avail 4.82: `--resident-experts` fell back to a 4.77 GiB copy,
  engine.log:33-45); e097 running. By 16:57 e097 also finished: `pressure_abort`, min_avail 5.96 at 4.00 GiB.
  **Admission MemAvailable falls 1.46x the copy** (from e094's 11.79): the engine sizes a copy against its own
  6 GiB headroom at copy time, but ~0.46x more is gone by the first request. Not found in expert_source.cpp's copy
  path (copied file pages are left to the OS cache, `reserve_exchanges` is ~0.25 GiB); measured, not explained.
  Usable budget <= ~3.75 GiB. Every queued 4 GiB job (e099-e103, e108) is doomed (two ~5 min attempts each).
- **r3-e109-gpuexact-resb25** submitted 16:54 with `ar_run.sh` in the background (prio 0, runs ahead of every
  queued job): e100's overrides with `--resident-budget-gib 2.5`, source 478bbbac+0 (first build of miss_exact.cu).
  e098 had already started, so e109 runs after it (~17:07). Override files written for the follow-ups (no runs
  yet): e110 (copy alone at 2.5 = e097 at 2.5, the A/B for B13's own share), e111 (e109 without timing +
  `--needles` = rule 4's repeat), e112 (check mode `STRATA_MISS_GPU_EXACT=2` at 2.5, for a texts change), e113 (B13 +
  mixed-ranked 3.5 GiB copy + e090's spec 8 config, timing on: the stack; est. admission ~6.7).
- Third read of miss_exact.cu, compile-focused (e109 is its first build): same target and include dir as
  iq_kernels.cu (`strata_kernels`, third_party/ggml), block offsets match ggml's block_iq3_s (qs 2, qh 66, signs 74,
  scales 106) and block_iq4_nl, intrinsics and their types (`__vsub4`, `__dp4a`, `_rn` float/double ops,
  `__double2ll_rn`, `__ushort_as_half`), NativeExpertLayout fields, shuffle lanes (block i's sum at lane 8(i&3) of
  round i>>2), alignment (g_xq 16-byte, 32-byte offsets). No defect found.
- **e098 collected (17:02): rule 4's repeat of e090 does not confirm its repetition number.** e098 (= e090's overrides
  + `--needles`, exe 108a5aec, source bec4857c): texts 1.0 on all nine, 19,068 slots, **needles 3/3**, min_avail
  11.72; review 35.64 (34.03 / 36.78 / 35.64), prose 23.88 (28.16 / 22.39 / 23.88), repetition **34.09** (34.09 /
  33.55 / 34.46) vs e090 36.69 / 26.16 / 35.52 and C4's confirm bar 34.5. Over e090 + e091 + e098 (9 repetition
  requests, same settings but COPY_MATCH in e091): median 34.46, range 33.55-36.51, against spec 4 + pool 9 SIBLINGS
  (e082-class) 31.7-33.7: **the spec 8 config is worth ~+1-1.5 tok/s (~+4%) on repetition, not +7%**, at review
  -1-3% and prose within noise. Not committed (no new source, its own bar missed). Owner note stays: for a
  repetition-heavy deployment e090's overrides are identical-text and pass needles, ~+4% repetition.
- **17:25 e109 collected: B13 mode 1 changed text (review 0.28 / 0.52 / 0.23) and hit `pressure_abort` (5.69) at a 2.5
  GiB copy.** Text: layer 0's gate/up are IQ3_XXS (type 18; engine.log:55 `does not cover layer 0`), so that layer's
  PCIe share ran the GPU kernels; the replica itself is untested by e109. Memory: ready line 7,011 MiB vs e094's
  12,752 (the copy's 1.46x explains ~3.65 GiB of the 5.6; the rest comes with `STRATA_NO_PCIE=0 --pcie-frac 1`,
  cause not found). Fix 3fa70777 (planner skips uncovered layers), run e114 at 1.5 GiB submitted (top block).
  e112/e111/e113 (old source, 2.5-3.5 GiB) are expected to change text / abort: read them for memory and e112's
  first unequal float (its layer should be an IQ3_XXS one).
- **Next (ranked):** (1) collect e112, e111, e113, e114 (top block C12 17:25); (2) e114 texts 1.0 = B13 proven on the
  IQ3_S layers: empty commit with the evidence, then round 4: an IQ3_XXS replica + find the ~2 GiB the PCIe share
  costs in MemAvailable (`/proc/meminfo` before/after `STRATA_NO_PCIE=0` at no copy) so the copy can grow; (3) e114
  texts changed: e112-style check mode on 3fa70777 at 1.5 GiB; (4) review: no lever above the spread this round
  (C8/C10/C11; round 4 B16).

### Continuation wrap-up (orchestrator, 2026-11-04 19:00-22:05 PST)

**Loop end.** The continuation ran 13:55-18:25 PST, 12 iterations. Iteration 12 exited 1 at 18:00 on the 5-hour
usage limit; the loop waited 25 minutes and stopped at its deadline. The queue drained by ~19:00.

**Every continuation result** (texts vs r3-baseline-f1/f2 on all nine, 19,068 slots unless noted; review / prose /
repetition tok/s):

| exp | settings (on r3-e076's unless noted) | review | prose | repetition | texts |
| --- | --- | ---: | ---: | ---: | --- |
| e080 | STRATA_POOL_SIBLINGS + pool 7 | 36.10 | 22.55 | 28.47 | 1.0 |
| e081 | + pool 11 | 35.00 | 20.75 | 24.78 | 1.0 |
| e082 | + pool 9 | 37.02 | 26.19 | 33.26 | 1.0 |
| e083 | STRATA_SPEC_STALE=32 | 36.73 | 23.17 | 30.66 | 1.0 |
| e084 | STRATA_COPY_MATCH=12 | 36.93 | 25.75 | 31.32 | 1.0 |
| e085 | STRATA_MTP_PRIORITY=2 | 36.98 | 25.85 | 30.68 | 1.0 |
| e086 / e087 | pool 9 pinned + --pool-tasks 64 / 128 | 36.47 / 36.87 | 26.81 / 26.69 | 33.63 / 33.74 | 1.0 |
| e089 | pool 9 pinned + needles (3/3) | 36.02 | 26.74 | 31.65 | 1.0 |
| e090 | spec 8 + IL_SPLIT + pool 9 pinned | 36.69 | 26.16 | 35.52 | 1.0 |
| e091 | e090 + COPY_MATCH=12 | 36.79 | 25.94 | 35.08 | 1.0 |
| e088 | IL rows 2 at 5-6 columns, spec 8 | 36.12 | 25.11 | 32.84 | 1.0 |
| e092 | STRATA_IQ3S_NEON_MT=1, pool 9 pinned, timing | 36.25 | 26.45 | 30.75 | 1.0 |
| e093 | STRATA_IQ3S_NEON_MT=2 | 36.47 | 25.85 | 31.06 | **0.33** |
| e094 | pool 9 pinned, timing (switch off) | 30.47 (stall) | 26.92 | 32.94 | 1.0 |
| e095 | STRATA_MISS_REPLICA_CHECK=1 (diagnostic) | 36.18 | 16.32 | 15.11 | 1.0 |
| e098 | e090 + needles (3/3) | 35.64 | 23.88 | 34.09 | 1.0 |
| e114 | STRATA_MISS_GPU_EXACT=1, 1.5 GiB RAM copy, pcie-frac 1, timing | 35.48 | 25.06 | 29.69 | 1.0 |
| e109 | GPU_EXACT before the coverage fix, 2.5 GiB | partial | | | **0.23** |
| e096, e097, e099-e103, e108, e111-e113 | RAM copy (--resident-experts or >= 2.5 GiB) | pressure_abort | | | |

**Branch cleanup.** The raw history is on the local branch `ar/decode-speed-r3c-raw` (3fa70777). `ar/decode-speed`
is rebuilt on bfc3a758 with new messages: 526a4386 STRATA_POOL_SIBLINGS (kept, the install), 77e0ba70 SPEC_STALE +
COPY_MATCH + MTP_PRIORITY (kept opt-in, no gain; the empty d4d760c5 folded in), 85d0d253 IQ3S_NEON_MT (kept opt-in,
no gain, mode 2 changes text; the replica check calls its kernel), fc92aee4 MISS_REPLICA_CHECK (diagnostic), 59692865
MISS_GPU_EXACT (b6f4b116 + 478bbbac + 3fa70777 squashed; texts identical in e114, slower). Dropped, never validly
measured: 74590f2b STRATA_RESIDENT_RANK_PROFILE (its runs all hit the memory floor) and 9343e5b7 STRATA_IQ4NL_NEON_MT
(never queued). Checked: 59692865 + those two commits = the raw head's tree exactly.

**Verification at 59692865 (exe 8964f913), queued 19:10, texts 1.0 on all nine in every run:**

| exp | settings | review | prose | repetition | needles |
| --- | --- | ---: | ---: | ---: | --- |
| e115 | every switch off (base only) | 35.52 | 18.35 | 16.09 | |
| e116 / e119 | r3's install (r3-e076) | 36.54 / 37.02 | 25.92 / 25.79 | 30.76 / 30.79 | |
| e117 / e118 | + pool 9 + STRATA_POOL_SIBLINGS | 36.83 / 36.95 | 26.69 / 26.84 | 32.39 / 32.87 | 3/3 (e118) |
| e120 | spec 8 + IL_SPLIT + pool 9 pinned (r3-e090) | 37.10 | 26.23 | 35.60 | |
| start script | `run-iq3_s.sh` -> fast-r3b | 36.74 | 26.32 | 32.69 | 3/3 |

e115 matches f1/f2 (35.47-35.61 / 18.43-18.58 / 16.44-16.58) and r3-e075: the default engine is unchanged.

**Install (22:05 PST).** `~/strata/engine-fast-r3b/strata` (8964f913) + `strata-iq3_s-fast-r3b.json` (r3-e118's
measured config with exe, log and port 8080); `run-iq3_s.sh` starts it; r3's start script kept as
`run-iq3_s-fast-r3.sh`. Scripts: `~/strata/install_r3b.sh`, `~/strata/verify_r3b.sh` (output
`~/strata/results/2026-11-04-fast-r3b-verify`, copied to `runs/r3-verify-r3b-startscript/`). The server is stopped,
as found. Not installed: the spec 8 config (e090 / e098 / e120: repetition 35.5 / 34.1 / 35.6, +13% on the mean,
but review 36.69 / 35.64 / 37.10 and prose 26.16 / 23.88 / 26.23 vary more than the install's).

**Harness.** `ar_collect.sh` takes a lock (lockf) since 16:30: two collects at once had logged r3-e095 twice.
