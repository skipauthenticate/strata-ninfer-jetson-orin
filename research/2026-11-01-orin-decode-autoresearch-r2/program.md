# Autoresearch round 2: IQ3_S decode on a Jetson AGX Orin 64 GB, from 33 to 90 tok/s

You are one iteration of an unattended research loop. A fresh agent runs this file again after you exit; everything
you learn must be written to files. Read, in order: `notes.md` (this round), `research-ideas.md` (literature and
novel ideas, when present), the last rows of `results.tsv`. Round 1's full history (103 runs, dead ends, kernel
findings) is in `~/workspace/strata-ar-lab/notes.md`; read the parts you need. Run one to six
experiments, record them, then stop.

## Goal
Raise the engine's **decode tok/s** for Qwen3.8-Flash-Next **IQ3_S at a 262,144-token context**, measured by
`./ar_run.sh` (median of three fresh 4,096-token prompts x 256 greedy tokens, engine-reported rate). The base config
is round 1's best (33.3 tok/s through the server): see `base-overrides.json`, applied to every run. The baselines of
this round are `runs/r2-baseline-*`. Target: **>= 90 tok/s**, lossless, context unchanged.

## Where the time goes (round 1, per verify window of ~2.45 accepted tokens, ~76-80 ms)
Routed experts ~23 ms (near bandwidth), dense projections ~22 ms, hyper-connection reads ~18 ms (2x off bandwidth),
drafting ~6 ms. Decode kernels behave as instruction-issue bound (DRAM streams ~180 GB/s; kernels reach 83-120).
90 tok/s means either ~27 ms per window at 2.45 tokens, or more tokens per window at a similar cost, or both. Kernel
tuning in round 1 gave 1-3% per change, so **prefer structural levers**: more accepted tokens per window (drafting,
tree or longer windows, suffix/prompt-lookup drafts), fewer bytes or launches per window (reusing weights across the
window's tokens, fusing stages, persistent decode loops), and overlap. Use `research-ideas.md` for candidates and
sources; add your own.

## New information (2026-11-01 11:50 PST): the 2-bit draft head
- (A non-public report the owner described is left out of this record.) Treat drafter quality and window length
  as the first lever, ahead of kernel polish: ~4 accepted tokens per window vs our ~2.45.
- **Strata's draft head runs its routed experts at 2 bits.** `Strata-data/mtp/rt/experts.bin` (708 MB) is Q2_0
  round-to-nearest (`tools/mtp_pack.py --experts q2_0`; its docstring says the format should be chosen by measured
  acceptance, which was never done); the dense projections are Q8_0. A 4-bit model normally carries a 4-bit draft
  layer. Round 1 showed drafter fidelity drives acceptance (`--mtp-hnorm stream` alone: 66-70% -> 72-79%).
- **Ready inputs** (built by the orchestrator, same BF16 checkpoint, ggml reference rounding):
  `/home/<user>/strata/Strata-data/mtp-hp/mtp-q4_0.gguf` (experts ~1.42 GB) and `mtp-q8_0.gguf` (~2.67 GB). Expert
  tensors keep the fused layout, quantized along the input axis: `mtp.layers.0.mlp.experts.gate_up_proj`
  [512, 1280, 2560] and `...down_proj` [512, 2560, 640]. Their dense tensors are BF16 (the runtime keeps using
  `mtp/rt/dense.bin`; only the routed experts change). Check `~/strata/mtp_hp.log` via a probe if unsure they exist.
- **Engine work needed**: the draft layer loads its experts as the Q2_0 blob (`src/core/mtp.cpp` ~312-331,
  `strata::kernels::cpu::BLOB`) and runs them with `moe_group_resident` (~944). Add an opt-in path, e.g.
  `STRATA_MTP_EXPERTS=<gguf>`, that loads the routed experts from one of these GGUFs (ggml's `gguf_init_from_file`
  is linked) and computes them with a kernel for that type (Q4_0/Q8_0 dot products exist in the tree: `--mtp-q4`
  dense path, ggml's MMVQ). Draft side only: verification is unchanged, so the text must be identical (PASS, 1.0).
  A **higher-precision drafter is allowed** under rule 1 (drafts are verified exactly).
- **Memory**: q4_0 adds ~0.71 GB over today's draft experts, q8_0 ~1.96 GB; min free is ~7.65 GiB against the
  6 GiB floor, so q8_0 likely needs a smaller `--expert-cache` (measure the slot size first).
- **Measure acceptance, not only tok/s**: mean accepted tokens per window for q2_0 vs q4_0 vs q8_0 (from `--stats` /
  `STRATA_DECODE_TIMING=1`), then retry `--spec 5`/`6` and `--suffix-draft`/`--lookup-chain` once acceptance rises.

## Rules (hard)
1. **Lossless only.** No lower precision for weights, KV or activations than the base; no dropped, pruned or skipped
   experts; no change to routing, top-k, sampling, attention math or model files. Allowed: memory placement, caching,
   scheduling, overlap, kernels computing the same math, graph capture, threads, drafting/verification policy (drafts
   are verified exactly), build flags that keep the math.
2. **Fixed by design** (the harness refuses overrides of them): `--max-context 262144`, `--kv int8`, `--pack`,
   `--native`, `--ple-gguf`. Keep the adaptive tier off (`--adapt-every 100000` is in the base).
3. **Gate.** With the cache size pinned, outputs are reproducible: the round 2 baselines should agree exactly
   (`python3 compare.py runs/r2-baseline-1/result.json runs/r2-baseline-*/result.json` shows `baseline_self_min`).
   A change is **PASS** if status is `ok` and `agreement_min` is 1.0 (identical text on all three prompts). If a
   change alters arithmetic order (different reduction, different window shapes), the text may change at a near-tie:
   mark it **REVIEW** in notes.md with the argument why the math is the same, and prove what you can with
   `./ar_probe.sh` (`--spec-follow` + `--window-hashes`, see strata-help.txt). Run `--needles` once (32K, 3/3) on
   anything you would keep.
4. **Improvement**: better only if decode_med beats the current best by more than the spread of the r2 baseline
   medians and a repeat run confirms it. Report outlier requests; do not let one decide.
5. **Allowed actions only** (enforced): edit files under `~/workspace/strata-ar/{src,include,cmake,CMakeLists.txt}`,
   `notes.md`, `research-ideas.md`, `overrides/*.json`, `TARGET_MET`; run `./ar_run.sh`, `./ar_probe.sh`,
   `python3 compare.py`, local `git -C ~/workspace/strata-ar ...` (no push), read-only shell tools, and
   `gh api repos/calvinvette/strata-ninfer-jetson-orin/contents/...` for the fork's docs. No ssh: the harness does all
   Jetson work, holds the shared GPU lock and enforces a 6 GiB free-RAM floor (`pressure_abort` = too much memory).
6. **Experiment ids start with `r2-`** (`r2-e001-slug` for runs, `r2-p001-slug` for probes), numbered after the last
   one used. The harness refuses other names.
7. **Commits**: commit every kept or REVIEW change on branch `ar/decode-speed` with a message that starts with the
   decode median (`decode 41.2 tok/s: ...`), says what changed in plain words, and names the evidence (exp ids,
   texts identical or REVIEW, needles). New behavior stays opt-in (an env switch or flag) so the default engine is
   unchanged. Revert anything else with `git -C ~/workspace/strata-ar checkout -- src include cmake CMakeLists.txt`.
   A build that fails twice: revert, note it, move on. Never bench a stale binary (`ar_run.sh` stops on a failed build).
8. **Budget**: at most ~60 minutes and six experiments per iteration. A structural change may take a whole iteration;
   leave it committed as work in progress only if it builds and passes the gate, otherwise revert and write down
   exactly where you stopped.

## How to run
```bash
# settings: write overrides/<exp>.json (applied after the base), then
./ar_run.sh r2-e012-spec6 "MTP spec 6 with longer windows" overrides/r2-e012-spec6.json
./ar_run.sh r2-e013-confirm "r2-e012 again, with needles" overrides/r2-e012-spec6.json --needles
# code: edit ~/workspace/strata-ar/src/..., then
./ar_run.sh r2-e014-window-reuse "share expert reads across the window's tokens"
# engine-level probe (no server) on the fixed 4,096-token prompt; {RUN} = this probe's Jetson folder:
./ar_probe.sh r2-p003-stats - "--max-new 64 --stats"
```
Overrides: `{"args": {"--flag": "value" | true | null}, "env": {"NAME": "value"}}`. `"STRATA_DECODE_TIMING": "1"`
adds per-request ms/window and stage lines to engine.log for paired comparisons (same texts -> same windows).

## Record keeping (every iteration)
- Append to `notes.md`: what you tried, numbers, conclusion, ranked next steps. Keep the "Current best" line at the
  top current (exp id, decode_med, commit, overrides file, PASS or REVIEW).
- If a PASS change reaches 90 tok/s and passed `--needles`, write `TARGET_MET` with its exp id and stop.
