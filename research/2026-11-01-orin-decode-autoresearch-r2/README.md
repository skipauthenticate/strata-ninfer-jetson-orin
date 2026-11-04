# Decode autoresearch, round 2, on a Jetson AGX Orin 64 GB, 2026-11-01

A second unattended loop, run the afternoon after [round 1](../2026-11-01-orin-decode-autoresearch/README.md). It
started from round 1's best settings, aimed much higher (90 tok/s), and was told to prefer structural changes over
kernel tuning. Same board (JetPack 7, CUDA 13.2), same model, same rules: lossless only, a fixed 262,144-token
context, and a change is kept only if the output text stays identical.

A third round on 2026-11-03 measured three workloads and reached 36.98 tok/s on this benchmark: see
[../2026-11-03-orin-decode-autoresearch-r3](../2026-11-03-orin-decode-autoresearch-r3/README.md).

## Result

Qwen3.8-Flash-Next IQ3_S, int8 KV. Decode is the engine-reported rate, the median of three fresh 4,096-token prompts
with 256 greedy tokens each, through `serve/server.py` and the community `benchmark.py`.

| Configuration | Decode tok/s [3 requests] | Prompt tok/s | TTFT s |
| --- | ---: | ---: | ---: |
| Setup's default configuration (round 1's starting point) | 23.7 | 234.7 | 17.5 |
| Round 2 baseline: round 1's fast build (`r2-baseline-1..3`) | 33.28–33.39 | 259–281 | 14.7–15.9 |
| **Best: `r2-e043`** | **35.18** [33.98, 35.41, 35.18] | 352.6 | 11.7 |
| Repeat with 32K needles: `r2-e044` | 34.93 [33.84, 35.25, 34.93] | 355.8 | 11.6 |
| Repeat at the pushed engine head: `r2-e048` | 35.09 [33.97, 35.43, 35.09] | 349.5 | 11.8 |

All three produced text identical to the round 2 baselines on all three prompts, and `r2-e044` found 3 of 3
needles. Engine: this branch's head (the runs log it as `4f8dacc1`, the same tree before two commit messages were
reworded). The minimum free memory was 7.0–7.2 GiB (6 GiB floor). The 90 tok/s goal was not reached: +5.6% decode and
about +30% prompt speed over round 1.

## What changed

All new behavior is opt-in; with none of these switches set, the engine is unchanged.

- **A 4-bit draft head.** Strata's draft (MTP) layer runs its 512 routed experts at Q2_0. `STRATA_MTP_EXPERTS=<gguf>`
  loads them from a GGUF built from the original BF16 checkpoint with `tools/mtp_pack.py` (`draft-head/mtp_hp.sh`)
  and runs them with the main model's expert kernel; `STRATA_MTP_EXPERTS_AS=iq4_xs` requantizes them at load to the
  faster IQ4_XS/IQ4_NL formats. Q4-level drafts: +3% accepted drafts, 2.46 → 2.68 tokens per window. Q8_0 drafts
  accept no more than Q4_0. Verification is unchanged, so the text is identical by construction.
- **A joint-probability draft gate.** `STRATA_SPEC_CUM=0,0.40,0.47`: draft j joins the window only while the product
  of the draft probabilities so far clears a threshold set from the measured cost of a verify column. About +0.5%.
- **Read-ahead for the SSD expert tier.** `STRATA_IO_PREFETCH=1` (an existing switch): +0.8% decode, +17–37% prompt
  speed.
- **A split hyper-connection down read.** `STRATA_HC_DOWN_RR=1`: two rows per warp for the HC down projection at
  1–6 tokens. Small (+0.3–0.7% together with the IQ4_XS draft head).
- Diagnostics: per-window-size timing (`STRATA_DECODE_TIMING`), drafter profiling (`STRATA_DRAFT_PROFILE`), the
  verify profiler split by window size, NEON for the routing look-ahead (`STRATA_LA_NEON`), and 5–6 column dense
  kernels (`STRATA_IL56`).

The best settings are `overrides/r2-e043-iq4xs-rr.json` on top of `base-overrides.json` (round 1's fast build).
To install them, follow [round 1's fast-build guide](../2026-11-01-orin-decode-autoresearch/fast-build/README.md),
which now includes round 2's draft head and switches (34.89 tok/s through the start script, needles 3/3).

## Why it stops near 35 tok/s

The loop measured the cost of a verify window directly: about **37 ms fixed plus 11.5 ms per verified token** at 2–4
tokens, and about 25 ms for a 5th. The drafts are already good (78–90% accepted at depths 1–3), so better drafting
cannot add many tokens per window, and longer windows (spec 5, prompt lookup, suffix drafts) cost more than they
return. Half of the per-token price is the experts each extra token routes to; the fixed 37 ms is the dense and
hyper-connection reads at about 100 GB/s. Reaching 90 tok/s would need both about 4 accepted tokens per window and a
much lower fixed cost; `research-ideas.md` has the byte model and the literature behind that estimate.

Closed on these prompts: Q8_0 drafts, the full 248K-row draft head, spec 5 with uncapped 5–6 column kernels, prompt
lookup chains, the routing look-ahead and miss-replay predictors for the SSD tier, several HC read layouts.

## Caveats

- **One workload**, the benchmark's synthetic code-review prompts, with a warm expert profile captured on them.
- **Stalls.** 3 of the round's first 30 requests stalled at ~300 ms windows (lookup-table rows read from the SSD);
  medians exclude nothing, so a stall can move one.
- **Losslessness** rests on identical text on three prompts and on each change keeping the same arithmetic (draft-
  side changes cannot alter the verified output). The engine's bit-exact check (`--spec-follow` with
  `--window-hashes`) was not run.
- **Not upstream-ready**: measured on the Orin only.

## Files

- `program.md`: the instructions each iteration ran with (one non-public report the owner mentioned is left out).
- `notes.md`: the agents' running log, measurements and dead ends, per iteration.
- `research-ideas.md`: the literature pass written before the loop (ranked candidates, byte model, feasibility).
- `results.tsv`: every measurement of the round.
- `overrides/`, `base-overrides.json`: the settings for each experiment.
- `draft-head/mtp_hp.sh`: how the Q4_0 and Q8_0 draft-head GGUFs were built.
- `harness/`: the scripts, with host names and paths replaced (`jetson` is an ssh alias, `/home/<user>` the board's
  home). New in this round: Jetson steps run detached (`harness/jrun.sh`, `harness/jetson/detach.sh`), so a laptop
  that sleeps only delays a result.
