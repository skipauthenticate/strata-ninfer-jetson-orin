# Autoresearch: faster IQ3_S decode for Strata on a Jetson AGX Orin 64 GB

You are one iteration of an unattended overnight research loop. A fresh agent runs this file again after you exit;
everything you learn must be written to files. Read `notes.md` and the last rows of `results.tsv` first, run one to
six experiments, record them, then stop.

## Goal
Raise the engine's **decode tok/s** for Qwen3.8-Flash-Next **IQ3_S at a 262,144-token context**, as measured by
`./ar_run.sh` (median of three fresh 4,096-token prompts x 256 greedy tokens, engine-reported rate).
Before tonight the installed config decoded 23.7 tok/s. The loop's own baseline is `runs/baseline-*` (base config:
warm expert profile, adaptive tier off; see below). Target: **>= 45.0 tok/s**, lossless.

## Rules (hard)
1. **Lossless only.** No lower precision for weights, KV or activations than the baseline; no dropped, pruned or
   skipped experts; no change to routing, top-k, sampling, attention math or model files. Allowed: memory placement,
   caching, scheduling, overlap, kernels computing the same math, graph capture, threads, drafting/verification
   policy (MTP drafts are verified exactly), build flags that keep the math.
2. **Fixed by design** (the harness refuses overrides of them): `--max-context 262144`, `--kv int8`, `--pack`,
   `--native`, `--ple-gguf`. The base adds `--expert-profile <warm profile> --adapt-every 100000`
   (`base-overrides.json`): keep adaptation off. The repository records GPU resets with the adaptive tier under
   memory pressure on an integrated GPU, and this Jetson is shared.
3. **Gate.** Baseline outputs are not reproducible run to run (text agreement as low as 0.02), so the text gate in
   `gate.json` is informational only. A change is PASS if it is math-preserving by construction (placement,
   scheduling, threads, drafting policy) or, for code, its window hashes match the base build's on the same
   `--spec-follow` continuation (notes.md explains the probe), and status is `ok`. Otherwise it is REVIEW. You may commit
   and build on a REVIEW change (put `REVIEW` in the commit message and argue in notes.md why it is the same math,
   e.g. an expert computed on the GPU instead of the CPU), but only the morning review can accept it. Pure refactors
   should give 1.0; if they do not, find out why. Use `--needles` (32K, 3 depths) once on any change you would keep.
   `./ar_probe.sh` with `--spec-follow` and `--window-hashes` (see strata-help.txt) can show whether two builds do the
   same arithmetic.
4. **Improvement**: count a change as better only if its decode_med beats the current best by more than the spread of
   the baseline medians (1.7 tok/s) and a repeat run confirms it. Single slow outlier requests (9-17 tok/s) occur in
   the baseline too; report them, do not let one decide.
5. **Never optimize `hit_rate`**: experts the GPU reads over the mapped ("PCIe") path are not counted as hits, so
   raising `--pcie-frac` can raise the hit rate while slowing decode. tok/s is the metric.
6. **Allowed actions only** (enforced): edit files under `~/workspace/strata-ar/{src,include,cmake,CMakeLists.txt}`,
   `notes.md`, `overrides/*.json`, `TARGET_MET`; run `./ar_run.sh`, `./ar_probe.sh`, `python3 compare.py`, local
   `git -C ~/workspace/strata-ar ...` (no push), read-only shell tools, and
   `gh api repos/calvinvette/strata-ninfer-jetson-orin/contents/...` for the fork's docs. No ssh: the harness does all
   Jetson work, holds the shared GPU lock and enforces a 6 GiB free-RAM floor (`pressure_abort` = too much memory).
7. **Leave the tree clean**: commit kept or REVIEW changes on branch `ar/decode-speed` with a message that starts with
   the decode median (`decode 31.2 tok/s: ...`); revert anything else with
   `git -C ~/workspace/strata-ar checkout -- src include cmake CMakeLists.txt`. A build that fails twice:
   revert, note it, move on. Never bench a stale binary: `ar_run.sh` stops on a failed build.
8. **Budget**: at most ~40 minutes and six experiments per iteration.

## How to run
```bash
# settings: write overrides/<exp>.json, then
./ar_run.sh e012-cache20k "expert cache 20000" overrides/e012-cache20k.json
./ar_run.sh e013-confirm "e012 again, with needles" overrides/e012-cache20k.json --needles
# code: edit ~/workspace/strata-ar/src/..., then
./ar_run.sh e014-dedupe "drop page-cache copies after the GPU upload"
# engine-level probe (no server) on the fixed 4,096-token prompt:
./ar_probe.sh p003-stats - "--max-new 64 --stats"
./ar_probe.sh p004-floor - "--max-new 16 --gpu-only-full --stats"
```
Overrides: `{"args": {"--flag": "value" | true (bare flag) | null (remove)}, "env": {"NAME": "value"}}`, applied
after the base. Each `ar_run.sh` takes ~3-5 minutes plus build time; it prints the result and appends a row to
`results.tsv`. Files per run: `runs/<exp>/{result.json,gate.json,engine.log,args.txt,build.log,source.diff}`.
Experiment ids must be new: `e<NNN>-<slug>` (runs) or `p<NNN>-<slug>` (probes), numbered after the last one used.

## What is known (notes.md is newer; trust it over this)
- Base config: file-backed experts (`--mmap-experts`; 46.84 GiB of IQ3_S experts, ~2 MiB each, 24,576 layer-expert
  pairs), automatic GPU expert cache (~18,350 pairs, ~34.9 GiB), MTP spec 4 / spec-min-p 0.5, KV int8, 262K context.
  Misses go to the CPU pool (12 Cortex-A78AE) or the GPU reads them from mapped host memory (probed 36.7 GB/s).
  Free RAM bottoms out near 6.8 GiB against the 6 GiB floor.
- Orin is unified memory (204.8 GB/s): GPU cache, host arena and page cache are the same DRAM; with mmap, cached
  experts also sit in the page cache. Physics: ~0.94 GiB of routed experts + ~1-1.5 GB dense/shared/head per token
  -> a 60-75 tok/s ceiling at realistic bandwidth before MTP. 23.7 tok/s is ~3x above that floor: the gap is the
  miss path and host synchronization, so slots and the miss path are the levers.
- Memory math says all 24,576 experts at 262K probably do not fit: 46.84 + ~3 KV + ~3 dense/head + 3 GiB workspace
  reserve + 6 GiB floor ~= 62 GiB > 61.4. `--kv-grow` (lossless: KV takes memory only as the context fills, the cache
  gets the rest) and removing duplicate copies are the ways to more slots. Results at 4K prompts then hold for short
  contexts only; say so in notes.
- Already measured in this fork (do not re-run as new ideas): CUDA graphs vs eager no effect on decode (two Q2_0
  7-block confirmations, 2026-10-16/19); mapped vs pread experts 1-3%; pool workers 4 vs 8 6.5-7.4%; `--ple-io`
  variants no benefit; the MTP window is +-15% at best (MTP4 +13% on short prompts, -9 to -11% at 7.5K, MTP2 -5%):
  tune it last, with `--spec-follow` so acceptance does not move the numbers.
- The fork's Nsight work found dense dequantization and GPU waits, not expert math, dominating its profiles.

## Suggested order (notes.md overrides this once it has evidence)
1. `p001` `--stats` on the base and `p002` `--gpu-only-full --stats`: where a decode step's time goes, and the GPU-only
   floor. If the floor is >= 22 ms/token, 45 tok/s is out of reach: record that and aim for the largest real gain.
2. More GPU slots: `--kv-grow`, explicit `--expert-cache N` steps, and why the auto size stops where it does (engine.log
   "expert cache auto" line; source in src/core). Dropping page-cache copies after upload (posix_fadvise) is a code arm.
3. The miss path on unified memory: copy-in vs mapped reads, `--pcie-frac`, `--resident-cpu-experts`, pool settings.
4. Host synchronization and dense-path costs the stats show; kernels last.

## Record keeping (every iteration)
- Append to `notes.md`: what you tried, numbers, conclusion, ranked next steps. Keep the "Current best" line at the
  top current (exp id, decode_med, commit, overrides file, PASS or REVIEW).
- If a PASS change reaches 45.0 tok/s and passed `--needles`, write `TARGET_MET` with its exp id and stop.
