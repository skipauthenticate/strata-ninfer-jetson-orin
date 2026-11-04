# Autoresearch round 3 notes

**FINAL (wrap-up, 2026-11-04 02:30 PST):** installed and verified through `run-iq3_s.sh`: review **36.98**, prose
**25.72**, repetition **31.12** tok/s (baselines f1/f2: 35.47-35.61 / 18.4-18.6 / 16.4-16.6), texts identical on all
nine, needles 3/3. Settings: round 2's + `--pool-workers 7` + `STRATA_MISS_ZEROCOPY=1` + `STRATA_SPEC_COST=1` +
`STRATA_SPEC_COST_TABLE=52.5,63.5,74.5,86.7`, engine 8f6ecdcd. Details: "Wrap-up" at the end of this file.

Current best (base, PASS): the installed round 2 best (r2-e043 settings, engine 8d466b5d, warm profile learned on
review), `base-overrides.json`. Per workload (r3-baseline-w1/w2, texts identical across both, 19,068 cache slots):
review **35.17 / 35.08**, prose **17.38 / 17.43**, repetition **15.52 / 14.24** (pr_mean ~16.5); cache hits 99.9 /
84.5-89.8 / 77-79%. 32K needles 3/3 (r3-baseline-needles, same settings).
**OWNER CHANGE (21:12 PST): ~5 GiB more free memory, but the expert cache did NOT grow (orchestrator, 21:40).**
The owner stopped two idle services on the board (marc1 worker, a small llama-server). r3-baseline-f1 / f2 (21:21 /
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
