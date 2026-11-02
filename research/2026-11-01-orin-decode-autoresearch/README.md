# Overnight decode autoresearch on a Jetson AGX Orin 64 GB, 2026-11-01

This is a research record, not a finished contribution. An unattended agent loop ran one experiment at a time on a
Jetson AGX Orin 64 GB (JetPack 7, CUDA 13.2) for about eight hours. Each experiment changed engine settings or code,
measured decode speed, and kept the change only if it helped and did not change the model's math. The engine changes
are the commits on this branch; this folder holds the rules, the harness and every measurement.

A second round the same afternoon took the best settings to 35.18 tok/s: see
[../2026-11-01-orin-decode-autoresearch-r2](../2026-11-01-orin-decode-autoresearch-r2/README.md).

## Result

Qwen3.8-Flash-Next IQ3_S with a 262,144-token context and int8 KV. Decode is the engine-reported rate, the median of
three fresh 4,096-token prompts with 256 greedy tokens each (the community `benchmark.py`).

| Configuration | Decode tok/s |
| --- | ---: |
| Setup's default configuration, the night before | 23.7 |
| Loop baseline: warm expert profile, adaptive cache off (`baseline-1..3`) | 24.5–26.2 |
| Best: `e096` / `e098` (repeat), commit `2298fe82` with `overrides/e096-hcup-pf48.json` | 34.40 / 34.31 |

The best configuration passed the 32K needle check (3/3), and its greedy output text was identical to the reference
run `e015` on all three prompts.

## What changed

Most gains are opt-in `STRATA_*` switches; the engine's default behavior is unchanged unless they are set:
`STRATA_DRAFT_VOCAB_TOP`, `STRATA_VRAM_GY`, `STRATA_GR_UP_LR`, `STRATA_MMVQ1_WARP`, `STRATA_NO_PCIE`,
`STRATA_HIT_COMBINE`, `STRATA_ATTN_PRE75`, `STRATA_EXP_PF`, `STRATA_HC_DOWN_WPB`, `STRATA_HC_UP_PF`, plus the existing
`STRATA_GR_FAST` and the settings `--kv-grow --expert-cache 14629`. `STRATA_BW_PROBE` and the profiler stamps are
diagnostics only.

Three commits change default kernels for every CUDA card: `9f1df88a` (integer rewrites in the Q6_K and IQ3_S dot
products), `fddcc9a1` and `4ba68980` (`__launch_bounds__` register caps). They were measured on the Orin only.

## Caveats

- **Losslessness** rests on two things: identical output text on three prompts, and each change keeping the same
  arithmetic by construction (same operations and order, only placement, scheduling or cache hints changed). The
  engine's bit-exact check (`--spec-follow` with `--window-hashes`) has not been run yet.
- **One workload.** The warm expert profile was captured on the benchmark's synthetic code prompts, so about 99.5% of
  experts came from the GPU cache. Mixed real traffic will hit the cache less, and switches such as `STRATA_NO_PCIE`
  assume few misses.
- **Screening level.** Three requests per run in one server process, one device. Some requests still stalled at 6–9
  tok/s when lookup-table rows were read from the SSD.
- **Not upstream-ready.** The default-kernel commits would need guards for `sm_87`, or measurements on other GPUs,
  before being proposed upstream.

## Files

- `program.md`: the instructions each loop iteration ran with.
- `notes.md`: the agents' running log, findings and dead ends.
- `results.tsv`: every measurement (103 rows).
- `overrides/`: the settings for each experiment.
- `base-overrides.json`: the base every run started from.
- `fast-build/`: how to run IQ3_S with this branch's engine and the best settings, and its verification through
  the server (33.28 tok/s decode, needles 3/3).
- `harness/`: the scripts. Host names and paths are replaced with placeholders: `jetson` is an ssh alias for the
  board, and `/home/<user>` is its home directory.
