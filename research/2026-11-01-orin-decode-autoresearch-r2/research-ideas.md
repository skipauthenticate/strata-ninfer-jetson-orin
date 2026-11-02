# Lossless decode speed for Qwen3.8-Flash-Next IQ3_S on Jetson AGX Orin 64 GB: literature and ideas

Written 2026-11-01 for autoresearch round 2. Target: 33.3 -> >= 90 tok/s, greedy output identical, 262,144-token
context, no precision, routing or attention changes. Every source cited below was opened; items the brief named but
that were not opened are marked as such.

## Measured in round 2 (iteration 1, notes.md) - read before picking an item
- Verify cost by window size (r2-e001): ~37 ms fixed + ~11.5 ms per column at 2-4 columns; a 5th column ~20 ms
  (dense IL kernels at 5 columns, r2-e005). Per-depth draft acceptance 88 / 79 / 82 % (and 82-86 % at depth 3):
  the drafter is good; the column price caps the window.
- Item 4 (trees): a node is a full column (~11.5 ms) against <= ~0.2 tokens a window from a runner-up: does not pay
  at today's column price.
- Item 13 is wrong as written: after a rejection at position k the MTP's input token is the verifier's correction
  a_k, not the draft d_{k+1}, so level-1 drafts cannot be precomputed from the window's drafts.
- Item 9 (cost-model stop rule): implemented as STRATA_SPEC_CUM (joint-probability gate), ~+0.5 %.
- Item 1, drafter precision (iteration 2): Q4_0 draft experts (STRATA_MTP_EXPERTS) +3 % accepted drafts, -4 % windows,
  34.54 tok/s with CUM (best); Q8_0 no better than Q4_0. Item 1's vocab part / N3 is dead: round 1 e019 measured the
  full head giving the same accepted counts as the 40,960-entry subset. Per-depth acceptance is now 90/78/85 %, so
  FastMTP-style fine-tuning has little room on these prompts; the window's column price (item 2) is the cap.
- Item 2, measured by stage and window size (iteration 3, r2-e014 per-T profile): at T2-T4 a column costs ~10.5 ms,
  of which ~5.4 ms is its new experts' bytes at ~140 GB/s, dense +2.0, HC +1.2. So even perfect column-agnostic
  kernels leave >= ~10 ms a column on this MoE; item 2 can make T5-T6 linear (today the dense IL kernels add +12.8 ms
  at 5 columns: CP-8 activation loads + 5 blocks a SM; rows 2 recovers ~3.5) but cannot make columns cheap. The
  gate/up kernel's 48 B local is in its dead fallback path (r2-e015), not the hot loop.
- Iteration 4: the 5-column activation cost is per sector, not per byte (r2-e017: splitting CP 8 into CP 4 + a
  1-wide plane made T5 verify 3.5-4.8 ms slower). The drafter is 6.3 ms a window (8.2%, r2-e019): round graph 2.4 ms
  at 1 catch-up row / 3.4 ms at 2-4 rows (a flat T > 1 path cost), chain steps 2.1 ms each (~88 GB/s, host round
  trip included), ~1.5 a window. Draft-side speedups are lossless by construction if the drafter's math is kept.
- Iteration 5 (r2-e020/e021, GPU stamps in the draft graphs): the chain step is GPU-bound (host round trip 0.03 ms);
  the drafter alone is 5.2 ms a window (round 2.0-2.2 ms at T1-T4, step 1.97 ms: draft head 0.53, moe 0.42 at ~75
  GB/s, q 0.20, attention 0.20, HC reads 0.28). Iteration 4's flat +0.9 ms at T >= 2 was the **verify commit**
  running beside the round. The commit graph is 1.57 ms GPU (GDN state replay + write, ~226 MB at ~144 GB/s), and
  overlapping it with the bandwidth-bound drafter hides only ~0.33 ms: **~1.2 ms a window of commit sits on the
  critical path, which makes N6 (bitwise commit-in-prologue) worth ~1-1.5 %**, the largest draft/commit-side item left.
- Iteration 6 (r2-e022/e023): draft policy is at its optimum (item 9 closed): CUM 0.50/0.55 neutral-worse, skipping
  provably cut chain steps ~0.1 %, and below p 0.5 the drafter is overconfident (round 1 e093: 10-43 % accepted).
  Remaining levers are verify-side only: N6, the GEMV rewrite (items 2-3), GR fusion (item 8).
- Iteration 7 (r2-e024..e029): item 5 closed on these prompts (`--lookup-chain 2` fires in ~1.7% of windows, suffix
  drafts ~1 window a request). Item 10 (I/O) paid: the existing opt-in `STRATA_IO_PREFETCH=1` (whole-blob preads
  instead of 4 KB mmap faults for the file tier) gave +0.8% decode (34.81, new best) and +17-37% prefill; major faults
  ~15,000 -> 90-600 a request. The CPU-miss path is I/O-bound: `jobs` (the blob fetch) is ~2-3 ms a window, the CPU
  compute 0.2-0.6; the read-ahead of predicted experts is nearly unused (3-12 used vs ~300 unused a request), so a
  better miss predictor (item 10 / N5 for experts) is worth up to ~3%. N6 re-estimated at ~0.4-0.8% (e014's `rec`
  column: the state write is +0.3 ms and each replayed row +0.19 ms inside the verify). The CPU topology dedups
  Orin's 12 cores to 4 (pool.cpp keys cores on (package, core_id)); `--pool-workers 7` halves the miss compute.
- Iteration 8 (r2-e030..e033): items 10 / 14 for experts are closed on this benchmark. On ARM the router look-ahead
  was a scalar loop and skipped ~78% of layers; on NEON (STRATA_LA_NEON) it runs every layer but router(L+1) on layer
  L's MoE input catches only ~10-25% of decode misses (top-10 to top-24): the 4-branch hyper-connections make
  consecutive layers' MoE inputs differ, so the Pre-gated/ProMoE premise fails here, and wrong reads slow the right
  ones on the SSD (K=24 -1%). Replaying earlier requests' misses (STRATA_MISS_REPLAY) catches 14-37%, growing with
  history; no gain at the median. Next structural lever: item 8 (HC fusion), then items 2-3.
- Iteration 9 (r2-e034..e039): item 8 re-sized: the HC norm is ~7.7 us a read (<= 0.6% to fold); the GDN "hc0 norm"
  excess is layer 1's PLE key/value projections (65 MB BF16 at ~140 GB/s), not a wait. Items 2-3: giving the HC down
  read 2 rows a warp (half the shared activation loads per FMA) left T2-T4 verify unchanged, so the GEMVs' growth with
  window size is NOT their shared loads; the limiter must be found (bisect probes) before the rewrite is designed.
  Item 1 (drafter precision): IQ4_XS gate/up + IQ4_NL down requantized from the Q8_0 GGUF (STRATA_MTP_EXPERTS_AS)
  accepts exactly as well as Q4_0 and drafts ~0.2 ms a window faster (noise level).
- Iteration 10 (r2-p002..p007, e040..e042): items 2-3 / 8 got an isolation bench (STRATA_BW_PROBE times the HC down and up
  reads alone at T 1-6 on fresh weights in a graph). The HC reads' growth with T is **intrinsic to the kernels** (alone:
  down 44.9 -> 61.1 us, up 41 -> 55 us at T1 -> T4; memory floor ~39 us), and the down read's compute side alone grows
  ~8.8 us a token, ~7x its FMA issue time, the same with half the shared loads (2 rows a warp). So the GEMV-family
  limiter is neither DRAM, shared bandwidth nor FMA issue; the suspects left are the dependent 8-FMA chain per dot8u
  and barrier-paced tiles with 1 block a SM. Splitting the 21-warp block into 2 blocks a SM of 6 warps (2 rows a warp,
  weights 2 tiles ahead; bitwise) cuts the down read alone to 43.3 / 46.4 / 48.9 / 52.3 us, but in the served pipeline
  only ~0.1-0.4 ms a T4 window came back (e041, see notes for e042's profile).
- Iteration 11 (r2-e043..e047): stacking the two small PASS opt-ins (IQ4_XS drafter + HC_DOWN_RR) made the formal best
  (r2-e043 35.18, repeat 34.93 + needles; ~+0.3-0.7% honest). Item 10/14's predictor is closed both ways (look-ahead
  off = no change, e045). A scan of ~135 decode switches found few untried exact ones; STRATA_SH_FORK_LATE=0 changes
  drafts (hidden-state bits) and is slower (e046). Never measured alone before: STRATA_EXPERT_V2 (S26 expert kernels
  for exactly IQ3_S/IQ4_NL 2560x640; e047). Gate/up is still the slowest large piece (~105 GB/s at T1 vs down ~121):
  round 1 listed a gate/up isolation bench for five iterations and never built it.

## 0. The numbers everything below is judged against

Architecture (from `Qwen/Qwen3.8-Flash-Next` config.json and the Qwen3.8-Next report): hidden 2560, 48 layers
(36 Gated DeltaNet + 12 QSA, one QSA every fourth layer), 512 routed experts top-10 + 1 shared, expert intermediate
640, vocab 248,320, hyper-connection (Gated Residual) with 4 branches and a rank-320 bottleneck, GDN state 48 value
heads x 128 x 128 fp32, QSA 24 query heads x 256 with 2 KV heads, indexer budget 2048 tokens in blocks of 4, n-gram
table (PLE) injected at one layer (layer id 2), MTP = one QSA layer sharing the embeddings.

Bytes per verify step, reconstructed from the shapes and matched against round 1's e100 profile (4-token window,
~2.45 accepted tokens, 70-75 ms):

| Phase | Reads | GB/step | Round-1 ms | GB/s reached |
| --- | --- | --- | --- | --- |
| Routed experts (gate/up IQ3_S, down IQ4_NL) | union of ~26-30 experts/layer x 48 x 2.04 MB | 2.6-2.9 | 21.9-23 | 122 / 149 |
| Dense projections (Q6_K/Q8_0) | ~2.7B params (GDN q,k,v,z,out; QSA q+gate,k,v,out, indexer) | 2.0-2.3 | 20-22 | 100-118 |
| Hyper-connection gates, BF16 | 2 GR modules/layer x (W_d 10240x320 + W_u 320x10240 + W_w) = 633M | 1.27 | 14.6-18 | 70-103 |
| Verify head Q6_K | 636M params, read once for all 4 positions | 0.52 | 4.5-5.3 | 97 |
| Draft: 3 x (MTP layer Q8_0 111 MiB + head subset 40,960 rows Q6_K 82 MiB) | | 0.61 | 5.6-9 | ~103 |
| Router BF16 | 48 x 2560 x 512 | 0.13 | 1.6 | 77 |
| Shared expert | 48 x 4.9M | ~0.19 | ~4 (side stream) | |
| GDN state fp32 read + write (36 x 3.1 MB), more if snapshotted per position | | 0.23-0.6 | ~2 | |
| QSA KV int8 + indexer | 4 tokens x 12 layers x 2048 selected | ~0.1 | 2.8 | |
| **Total** | | **7.6-8.3** (engine counts ~6.5) | **70-75** | **~100 average** |

Consequences:

- Bandwidth floor with today's bytes: 6.5-8.3 GB at the 180 GB/s the board streams = 36-46 ms/step. At 2.45
  tokens/step that is **53-68 tok/s**. 90 tok/s at 2.45 tokens/step needs 27 ms/step = 240-300 GB/s, above the
  204.8 GB/s peak. **At today's tokens per step, 90 is physically impossible on this board with this file.**
- Fixed bytes that do not grow with the window: dense 2.2 + HC 1.27 + head 0.52 + router 0.13 = **4.1 GB**. Bytes
  that grow: experts (~0.55-0.7 GB per extra verified token after dedup) and drafts (0.2 GB per draft step).
- So the only road to 90 is **more accepted tokens per step and kernels near the bus limit at the same time**: with a
  4-draft chain (5 nodes) and 8.4 GB/step, 180 GB/s gives 47 ms, so 3.3 tokens -> 70 tok/s and 4.0 tokens -> 85
  tok/s; at 195 GB/s (95 % of peak) 4.0 tokens -> 93 tok/s. Each factor (tokens/step and GB/s) must improve ~1.65x.
- The verify window shape matters for the kernels, not just the bytes: round 1's spec 5 lost 13 % (e029, 25.03 vs
  28.76) and the 5-6 column IL kernels (e030) did not fix it. More tokens per window pays only once the GEMV kernels
  keep their GB/s from 4 to 8+ columns.

Exactness rule used throughout: drafting and verification-policy changes are lossless by construction (the
verifier is unchanged and compares argmaxes). Kernel changes that reorder float sums can flip a greedy near-tie, so
they are PASS only if the gate texts are identical, otherwise REVIEW with `--spec-follow` + `--window-hashes`.

## 1. Ranked candidates (most promising first)

### 1. Drafter acceptance: FastMTP-style position-shared fine-tuning of the MTP head, and a workload-chosen draft vocabulary

**Mechanism.** The shipped MTP head was trained for one step ahead; engines reuse it recursively for 3 drafts, and
acceptance decays fast at positions 2-3 (Qwen3-Next-80B base on GSM8K: 0.897 / 0.719 / 0.476 per position; after
FastMTP-style fine-tuning 0.912 / 0.776 / 0.616). FastMTP fine-tunes one position-shared head on data generated by
the target model itself, teacher-forced through k recursive steps with decaying loss weights, initialised from the
native `mtp.*` weights; it reports 2.03x average speedup, 82 % over vanilla MTP, output lossless (the verifier is the
target). The Qwen3.8-Next report itself quotes a **mean accepted length of 4.06 with four MTP steps** for this
architecture, against Strata's ~2.45-3.03 per window; part of that gap is the engine's draft head subset (the first
40,960 vocab ids), part is 3 drafts vs 4, part is the recursive-reuse mismatch. The draft vocabulary is already a
file (`--mtp-draft-vocab FILE`): rebuild it from token frequencies of the target workload (plus every token id in the
current prompt, since copied tokens are the ones a fixed subset misses) instead of the first 40,960 ids. Same bytes,
better coverage. FastMTP's "language-aware dynamic vocabulary compression" is the same idea.
**Exactness.** Exact: drafts are proposals; the backbone verifies with unchanged math.
**Gain.** Tokens/step 2.45 -> 3.0-3.4 (chain of 3) or 3.3-4.0 (chain of 4 with item 2's kernels). Bytes per step
unchanged for the vocab change; +0.2 GB per added draft step plus ~0.6 GB of extra expert union per added verified
token. Net 1.2-1.5x. This is the single largest lever and the only one that can push past ~70 tok/s.
**Effort.** S for the vocab file (CPU-side, no engine change). M for fine-tuning: a few GPU-hours on a cloud box,
data = the target model's own outputs on representative prompts; the result is a new `mtp.*` Q8_0/Q6_K tensor pair
that Strata already loads. The quantization of the new head must follow the same recipe so the drafter numerics stay
close to the verifier (round 1's per-stream hnorm, e090/e092, raised acceptance from 66-70 % to 72-79 % purely by
matching the reference graph; drafter fidelity matters).
**Sources.** FastMTP, Cai et al., 2025, https://arxiv.org/abs/2509.18362. Red Hat / vLLM FastMTP article with the
per-position numbers, 2026-09-08, https://developers.redhat.com/articles/2026/09/08/optimize-vllm-speculative-decoding-fastmtp-heads.
Qwen3.8-Next report (mean accepted length 4.06/4.07), Qwen team, 2026, https://arxiv.org/html/2608.30320.
Medusa (frozen-backbone heads are lossless), Cai et al., 2024, https://arxiv.org/abs/2401.10774.

### 2. Column-count-agnostic verify GEMVs: dequantize once, dot against N columns from registers, same GB/s for N = 1..8

**Mechanism.** Every weight byte of the dense, HC, head and expert paths is dequantized once per step and used for
every token in the window. Round 1's kernels are specialised for <= 4 columns (IL rows classes, `native_gu_multi_kernel<21>`),
and 5-6 column variants lost. The kernel family has to be rewritten so that per-column dot products are added
without touching the dequant path or the reduction tree: load a 128-bit weight fragment, dequant to registers once,
then N independent dp4a/FMA chains against N activation fragments held in shared memory (N x 2560 x int8 = 20 KB for
N = 8, trivially fits). Lan (2026) measured why this is subtle on MoE: a deduplicating expert kernel is slower per
byte than a per-slot kernel on every engine he tested (bandwidth ratio 0.32-0.75) because per-slot re-reads hit cache
and dedup adds launches; on Orin with a 4 MB L2 and 2 MB experts the per-slot re-reads would not hit, so dedup is the
right choice, but the dedup kernel must not lose occupancy as N grows. Cohere measured the target cost of verifying 4
vs 1 token at batch 1 as 1/0.80 = 1.25x for a k=8/N=128 MoE; that ratio is the thing to reproduce here.
**Exactness.** Bitwise if each column's dot product keeps the same summation order as the 1-column kernel. A changed
reduction tree is REVIEW.
**Gain.** Enabler for items 1, 4, 5 (no direct tok/s on its own). Without it, every token added to the window costs
more than its bytes.
**Effort.** M-L: the dense/HC/head GEMVs and the expert gate/up/down kernels, in CUDA, with per-N launch bounds.
**Sources.** Lan, 2026, "Speculative Decoding for Mixture-of-Experts Models: Expert Bytes, Kernel Bandwidth and the
Best Draft Length", https://arxiv.org/abs/2610.34440 (Table 1: u(2) 0.72-0.83, u(8) 0.36-0.62, r(n) 0.32-0.75).
Cohere, "Why MoE models get more from speculative decoding", Ranjan, 2026-04-21,
https://cohere.com/blog/mixture-of-experts-models-get-more-from-speculative-decoding (unique experts 8.0 / 25.4 /
59.3 / 109.1 at 1 / 4 / 16 / 128 tokens; Tt(1)/Tt(4) = 0.80 at batch 1).

### 3. Kernels to the bus limit: dense, HC and head from 70-118 GB/s to >= 150 GB/s

**Mechanism.** Round 1 ended with the diagnosis "instruction issue and occupancy bound, not memory bound", and a
36 ms floor at 180 GB/s. The gate/up kernel runs at 122 GB/s with a 48-byte local-memory array in the hot loop
(round 1's top next step); dense GEMVs at 100-118 GB/s; HC gate GEMVs at 70-103 GB/s (W_d is 6.5 MB per sublayer:
too small to fill 16 SMs for long, so launch ramp and tail dominate). Measures that are pure engineering and keep
the math: (a) one wave of blocks sized to the SM count with a grid-stride over rows (VRAM_GY=8 was the round 1
optimum); (b) register staging of the activation fragments instead of shared-memory re-reads; (c) the Marlin trick,
an **offline permutation of the quantized weight layout** so that each thread's 128-bit load holds exactly its
nibbles, scales and signs in the order the dequant consumes them, removing shuffles and table-lookups per weight
(a pure byte permutation, bit-identical values); (d) make sure every per-step weight lives in `cudaMalloc` memory:
on Orin, pinned host memory is **uncached in the GPU L2** (CUDA for Tegra, Table 1) and managed memory with
`concurrentManagedAccess = 0` needs driver cache maintenance at every sync; neither should hold a hot weight.
**Exactness.** (a)(b)(d) bitwise if the per-row reduction order is kept; (c) bitwise by construction.
**Gain.** Dense 20 -> ~13 ms, HC 14.6 -> ~9, head 5.3 -> ~3.3, experts 21.9 -> ~18: about -18 ms/step, 70 -> ~52
ms, 33 -> ~47 tok/s at today's 2.45 tokens. This is the second half of the 90 tok/s product.
**Effort.** L (a kernel family), S for (d). Round 1 shows each individual knob gives 1-3 %; the structural version is
rewriting the GEMV family once (item 2 and this item are the same rewrite).
**Sources.** MARLIN, Frantar et al. (ISTA), 2024, https://arxiv.org/abs/2408.11743. CUDA for Tegra application
note (memory types, pinned = iGPU uncached, managed-memory coherence cost),
https://docs.nvidia.com/cuda/cuda-for-tegra-appnote/index.html. Hazy Research "No Bubbles" (78 % of H100
bandwidth at batch 1) and Cohere megakernel (62 % of speed of light) give the achievable fraction on much bigger
GPUs; 85-90 % on Orin is optimistic.

### 4. Tree speculation at the same depth, with batched MTP levels (width is free on the draft side)

**Mechanism.** Keep depth 3-4 but let each draft level carry the MTP's top-2 (or top-3 at level 1), pruned to the
~8 highest joint-probability nodes EAGLE-2 style (the MTP's softmax is a usable confidence proxy). The point specific
to this engine: a draft level for all nodes at the same depth is **one multi-column pass over the MTP layer and draft
head**, so the draft bytes (0.2 GB per level) do not grow with width; only the verify expert union grows. SpecInfer's
tree attention mask handles the 12 QSA layers; the 36 GDN layers need per-path recurrence from one checkpoint
(item 6 is the prerequisite), and the hyper-connection streams are per-node activations, no extra weights.
**Exactness.** Exact under greedy: the accepted path is the one whose tokens equal the backbone argmaxes along it.
**Gain.** Tokens/step +0.4 to +0.8 over a chain of the same depth (EAGLE-2 reports 20-40 % over EAGLE-1's static
tree; Cohere's acceptance length 2.73 at batch 1 for a chain). Cost: union bytes for 8 nodes ~3.9 GB vs 2.74 for 4
(Lan's u(8) ~0.5), about +1.1 GB = +6 ms at 180 GB/s. Today (kernels at ~100 GB/s and 4-column specialised) it is
roughly neutral; after items 2-3 it is +10-20 %.
**Effort.** M: tree mask in the QSA kernel, path-wise GDN recurrence, tree-aware hyper-connection write-back, the
pruning policy. Draft side: top-k on the 40,960-row draft logits (already computed for the argmax).
**Sources.** SpecInfer, Miao et al., ASPLOS 2024, https://arxiv.org/abs/2305.09781. EAGLE-2, Li et al., 2024,
https://arxiv.org/abs/2406.16858. EAGLE-3, Li et al., NeurIPS 2025, https://arxiv.org/abs/2503.01840 (a trained
drafter on fused multi-layer features is the stronger version of item 1 if the MTP head plateaus). Sequoia, Chen
et al., 2024, https://arxiv.org/abs/2402.12374 (hardware-aware tree size; its big trees assume offloading, see
section 3). Cascade / Utility-driven SD for MoE, Saxena et al., 2025, https://arxiv.org/abs/2506.20675 (draft tokens
activate 2-3x the expert data; speculation can slow MoE 1.5x; choose K from measured utility).

### 5. Suffix-automaton and prompt-lookup drafts on the idle CPU, hybridised with the MTP

**Mechanism.** The engine already has `--suffix-draft N` (default 3, grows the window by 2 up to 8 "where a repeat is
likely"), `--lookup-chain K` (off by default: prompt-lookup drafts continuing the MTP drafts) and `--mtp-max-t`.
Round 1 notes that spec 4 windows never exceeded 4 tokens, so the growth rule is not firing on the benchmark prompts
or is gated too tightly. SuffixDecoding keeps a suffix tree over prompt + earlier outputs on the CPU and proposes
long drafts only when the empirical continuation frequency is high; it is 2.8x faster than EAGLE-2/3 on agentic
and Text-to-SQL work and its speculation length adapts per step. On this board the 12 A78AE cores are idle during
decode and the suffix draft costs zero GPU bytes, so when it fires a window of 8-12 tokens costs only the extra
expert union (~0.6 GB per token) against 4.1 GB of fixed bytes; a 10-token window accepted at 8 gives ~8 tokens for
~10.5 GB = 58 ms at 180 GB/s = ~135 tok/s during the burst.
**Exactness.** Exact (verified drafts).
**Gain.** Workload dependent: large on summarisation, edits, code with repeats (PLD reports ~2.4x on CNN/DM and QA);
~0 on free prose. For the 4,096-token-prompt benchmark it depends on how much the outputs copy the prompt. First
experiment is diagnostic: histogram window sizes (`--window-hashes`) with `--suffix-draft 2`, `--lookup-chain 4`,
`--lookup-chain-min 2`, `--mtp-max-t 4`, and check whether any window exceeds 4.
**Effort.** S for the flag sweep; M to make the suffix automaton incremental over outputs and to let the window
reach 8-12 without the kernel penalty (item 2).
**Sources.** SuffixDecoding, Oliaro et al., NeurIPS 2025 spotlight, https://arxiv.org/abs/2411.04975. Prompt
lookup decoding, Saxena, 2023, https://github.com/apoorvumang/prompt-lookup-decoding. Token Recycling, Luo et al.,
ACL 2025, https://arxiv.org/abs/2408.08696 (reuse the target's own top-k candidates as a 2 MB draft graph).
Lookahead decoding, Fu et al., 2024, https://arxiv.org/abs/2402.02057 (exact, but see section 3 for why its n-gram
pool is a poor fit for MoE bytes).

### 6. GDN state: cache inputs, not state (ReplaySSM), one checkpoint per step, rollback = pointer move

**Mechanism.** A verify window on a recurrent layer has to be able to roll back to the accepted position. The usual
way snapshots the 3.1 MB state per layer per position (4 x 113 MB of writes per step) or re-runs the recurrence.
ReplaySSM keeps one checkpoint plus a ring buffer of the per-token inputs (for Gated DeltaNet a correction term u
instead of raw v, plus k and the decay), computes outputs from checkpoint + buffered inputs, and flushes to the
checkpoint only when the buffer fills. Rollback discards ring entries. It also lets the verify kernel evaluate all
positions from one checkpoint, which is exactly what tree verification (item 4) needs on GDN layers.
**Exactness.** Tri Dao states "mathematically equivalent up to floating-point error", so the parallel form is
REVIEW. A sequential-replay variant (apply the accepted prefix in the original order inside the next step's GDN
prologue) is bitwise identical and still removes the per-position snapshots.
**Gain.** 1-3 ms/step today (state traffic 0.23-0.6 GB -> ~0.23 GB); enabler for item 4. ReplaySSM reports 1.87-1.96x
for speculative decoding on Mamba-2/GDN models in vLLM, but at serving batch sizes on B300s, so do not transfer
the number.
**Effort.** M, inside the GDN recurrence kernel and the window commit path.
**Source.** ReplaySSM: Cache SSM Inputs, Not State, Tri Dao, 2026, https://tridao.me/blog/2026/replayssm/.
Gated Delta Networks, Yang, Kautz, Hatamizadeh, ICLR 2025, https://arxiv.org/abs/2412.06464 (the recurrence).

### 7. Persistent decode megakernel (or per-layer fused phases) with counter dependencies and weight prefetch into bubbles

**Mechanism.** A step runs ~1,000 small kernels (48 layers x ~20) under CUDA graphs. Every boundary is a full-grid
barrier: the slowest SM sets the pace, the next kernel's weight loads cannot start until the previous drains, and
on 16 SMs a 2 MB kernel is only ~10 us of DRAM time, so ramp/tail is a large share. Round 1 saw this as "waits and
combine 1.9 ms", route/doorbell ~1 ms, HC norm 0.8 ms, conv/ab ~2 ms, and many launches that mostly exit
(`copy_rows_from_mapped`, `moe_hit_add`). Hazy Research's megakernel for Llama-1B replaced ~100 kernels by one
interpreter kernel with a per-SM instruction stream, global-memory counters for dependencies and shared-memory
pages handed to the next instruction so its weight loads start early (78 % of H100 bandwidth, 2.5x vLLM at batch 1).
Cohere's version adds dynamic work stealing for attention and MoE tiles and reports that weights are prefetched
before activation dependencies resolve. MPK compiles this automatically (up to 1.7x latency). On Orin the useful
prefetch depth is bounded by the 4 MB L2 (~20 us of DRAM time), which matches the bubble sizes.
**Exactness.** Bitwise if each task keeps the kernel it replaces.
**Gain.** 5-10 ms/step (7-14 %) by removing launch gaps and tails; it also makes items 2-3 easier because the
GEMV "task" can be sized to a full wave regardless of the tensor.
**Effort.** L. A staged path exists: first fuse within a sublayer (GR read -> norm -> projection; router -> top-k ->
expert dispatch) and the tiny GDN conv/ab/gate kernels; then one persistent kernel per layer; then one per step.
**Sources.** Spector et al., Hazy Research, "Look Ma, No Bubbles", 2025-05-27,
https://hazyresearch.stanford.edu/blog/2025-05-27-no-bubbles. Tong, Zhu, Wang, Cohere, "Megakernels", 2026-09-08,
https://cohere.com/blog/megakernels (292 tok/s at batch 1 on H100, 1.58x vLLM, counting-barrier pitfalls). MPK,
Cheng et al., OSDI 2026, https://arxiv.org/abs/2512.22219.

### 8. Fuse the Gated Residual read/write with its neighbours

**Mechanism.** Per sublayer the GR read is: RMS-norm 4 branches -> W_d (10240 -> 320) -> SiLU -> W_u (320 -> 10240)
-> sigmoid -> gated mean of the branches; the write is a 4-scalar gate times the sublayer output added to each
branch. The Qwen report says their training kernel fuses read, write and normalisation into one pass over the
widened stream. Here W_d and W_u are 6.5 MB each, read at 70-103 GB/s because each is its own launch with a
dependency between them. Fusing norm + W_d + SiLU + W_u + sigmoid + gated sum into one kernel (W_u's load issued
while W_d's reduction completes) and the write into the preceding projection's epilogue removes 4-5 launches per
sublayer and the round trips through HBM for the 320-vector.
**Exactness.** Bitwise if the per-row reduction order is kept.
**Gain.** HC 14.6 -> ~9 ms if it reaches ~140 GB/s: 5-6 ms/step (8 %). Round 1's HC prefetch and warp balancing
got -0.3/-0.4 ms each; the fusion is the structural version.
**Effort.** M.
**Source.** Qwen3.8-Next report (GR equations 31-34, fused kernel), https://arxiv.org/html/2608.30320.
Hyper-Connections, Zhu et al., 2024, https://arxiv.org/abs/2409.19606 (the general form).

### 9. Draft-length policy from a measured cost model instead of a fixed min-p

**Mechanism.** The marginal cost of one more draft token is one MTP pass (0.2 GB) plus the extra expert union
(~0.6 GB) plus the kernel penalty for the wider window; the marginal gain is p(accept) x (step time / tokens per
step). With today's numbers the break-even acceptance is ~(1.1+3.3)/(70/2.45) ~ 0.15, far below the min-p 0.5
in use, yet min-p 0.3/0.4 did not win in round 1 (e014, e093). That says the kernel penalty dominates (item 2).
Once it is gone, pick the stop rule online: Cascade measures utility = tokens gained / verification cost per
request and tests K values periodically; SpecDec++ trains a tiny acceptance head on the drafter and stops when
P(at least one rejection) crosses a threshold; Lan gives the closed form for the best draft length as a staircase in
acceptance with measured per-kernel bandwidths.
**Exactness.** Exact.
**Gain.** 3-8 % after item 2; ~0 before.
**Effort.** S (policy code on the host, per-position acceptance counters already exist).
**Sources.** Cascade, Saxena et al., 2025, https://arxiv.org/abs/2506.20675. SpecDec++, Huang, Guo, Wang, COLM 2025,
https://arxiv.org/abs/2405.19715. Lan, 2026, https://arxiv.org/abs/2610.34440.

### 10. PLE and expert-miss stalls: prefetch rows for drafted tokens and their alternatives; size the row cache

**Mechanism.** Round 1 saw ~1 in 3 requests stall (6-9 tok/s requests, `per-layer host 15.05 [CPU 14.80]`), from
n-gram row gathers off the SSD and CPU-expert page faults. The n-gram key for a verify position depends only on the
last 3 token ids, which are known the moment the drafter emits them, so the 16 row reads for position i can be
issued while the drafter is still working on position i+1 (today they can only start after the window is final).
Prefetch also the rows for the drafter's top-2 alternative at each level and for the verify head's top-2 at the
last position: when a draft is rejected, the correction token's rows are then likely cached. `--ple-row-cache`
(default 1,048,576 rows x 90 B = 94 MB) and `--ple-inflight 256` were never tuned; `--ple-io ram` locks the table,
which is only possible if the shard fits beside 46.8 GiB of experts (free RAM is ~7.7 GiB, floor 6). For expert
misses (0.1-0.3 %), the 15 ms is an SSD page fault, not the copy: the pinned set cannot grow (RAM), so the lever is
`--resident-cpu-experts` with a static profile, or freeing RAM elsewhere (`--kv-resident` moves QSA K/V to pinned
RAM and gives the VRAM to expert slots).
**Exactness.** Exact (data placement only).
**Gain.** Mean +1-3 %, tail requests +50-100 %. Cheap and makes the medians trustworthy.
**Effort.** S for flags; S-M for alternative-token prefetch (host I/O thread already exists: `--ple-sync-submit` A/B).
**Source.** Qwen3.8-Next report (n-gram tables prefetched asynchronously, injected at one layer so prefetch overlaps
layer 1), https://arxiv.org/html/2608.30320. Engine flags: strata-help.txt.

### 11. Lossless entropy coding of the BF16 hyper-connection and router weights (DFloat11 / ZipNN)

**Mechanism.** The GR gates (1.27 GB/step) and the router (0.13 GB) are BF16, 19 % of all bytes, and may not be
quantized. BF16 exponents have low entropy: DFloat11 entropy-codes BF16 weights to ~70 % of their size with
bit-for-bit identical outputs and decodes on the GPU with hierarchical lookup tables in SRAM; ZipNN reports ~33 %
savings for popular models. Applied to W_d/W_u/W_w and the router: 1.4 GB -> ~1.0 GB per step.
**Exactness.** Bitwise (decoded values are the original BF16).
**Gain.** Up to -0.4 GB = -2.2 ms at 180 GB/s (3 %). Risk: DFloat11's decode is a table walk per weight; on 16
Ampere SMs that already look issue-bound it can cost more than the bytes it saves. Only worth it after items 3 and 8
turn the HC kernels bandwidth-bound; measure decode throughput in isolation first.
**Effort.** M-L (a decode kernel fused into the GR GEMV, plus an offline encoder).
**Sources.** DFloat11, Zhang et al., NeurIPS 2025, https://arxiv.org/abs/2504.11651. ZipNN, Hershcovitch et al.,
2024, https://arxiv.org/abs/2411.05239.

### 12. L2 access-policy windows for the few tensors that are reused within a step

**Mechanism.** Orin's L2 is 4 MB (the data sheet figure; the technical-brief PDF did not parse here), so weight
persistence is out. What is re-read within a step and fits: the window's activations and their int8 copies
(~4 x 2560 x (4 branches + 1) x 4 B = 200 KB), the IQ3_S/Q6_K dequant tables, routing tables and expert index
lists, the 320-vectors of the GR bottleneck. Mark them persisting with `cudaStreamAttributeAccessPolicyWindow`
(or per kernel node in the graphs) and the weight streams `cudaAccessPropertyStreaming` so they do not evict them.
Check `persistingL2CacheMaxSize` on sm_87 first; it may be 0.
**Exactness.** Exact.
**Gain.** <= 1-2 %. Round 1's L2 prefetch switches (EXP_PF, HC_UP_PF) are already in this family.
**Effort.** S.
**Source.** CUDA Programming Guide, L2 cache control (set-aside, hitRatio, graph kernel-node attribute),
https://docs.nvidia.com/cuda/cuda-programming-guide/04-special-topics/l2-cache-control.html.

### 13. Acceptance-point-agnostic level-1 drafting overlapped with the verify head

**Mechanism.** The MTP's input at position i is (final hidden state h_i, embedding of token i+1). For positions 0..2
of the window the "next token" is the draft already in the window, so level-1 drafting for those positions does
not depend on the head's argmax; only position 3 (the bonus token) does. Run the level-1 MTP pass for all four
positions as one 4-column GEMV (same weight bytes as one column) on a side stream while the 0.52 GB head GEMV and
the top-k run, then keep the column at the actual acceptance point. The dependency chain head -> argmax -> draft
collapses to head -> argmax -> (draft already done for 3 of 4 outcomes).
**Exactness.** Exact (unused columns are discarded).
**Gain.** ~1-2 ms/step (the head's tail and the 0.6 ms top-k are filled with draft bytes; one of three draft passes
leaves the critical path 75 % of the time). Compounds with item 4 (the level-1 children are the same GEMV).
**Effort.** S-M (stream scheduling and a 4-column MTP launch).
**Source.** Original to this note; the pattern is PEARL's "post-verify" overlap without a second device
(PEARL, Liu et al., ICLR 2025, https://arxiv.org/abs/2408.11850).

### 14. Router-predicted L2 warm-up of likely experts (prefetch only; the real router still decides)

**Mechanism.** The routing bubble per layer (HC read -> norm -> router GEMV -> top-10 -> doorbell, ~25 us) idles
DRAM. A cheap predictor from the previous layer's hidden state (Pre-gated MoE / ProMoE / SpecPrefetch / APEX lineage)
can issue L2 prefetches for the first ~100 KB of the 16 most likely experts so the expert kernel starts on warm
lines. Unlike those papers nothing is loaded across a bus here (experts already sit in DRAM), so the gain is only
the bubble.
**Exactness.** Exact (prefetch only; APEX's "correctness-preserving mode" and SpecPrefetch's frozen router are the
same contract).
**Gain.** <= 1 ms/step; round 1's router prefetch (e099) was neutral. Low priority.
**Effort.** S-M.
**Sources.** Pre-gated MoE, Hwang et al., 2023/2024, https://arxiv.org/abs/2308.12066 (changes routing; lossy).
ProMoE, Song et al., 2024/2025, https://arxiv.org/abs/2410.22134. SpecPrefetch, Kong et al., 2026,
https://arxiv.org/abs/2607.24787 (frozen router, prediction errors cost bandwidth not outputs). APEX, Kanani et al.,
2026, https://arxiv.org/abs/2608.11688.

## 2. Novel ideas for this exact architecture (not covered by the papers)

N1. **Width-free draft trees via batched MTP levels** (item 4's engine-specific core). Because the MTP is one QSA
layer plus a shared head, all children at one tree depth are one multi-column pass; the draft side costs the same
0.2 GB whether the level has 1 or 4 nodes. The verify union is the only cost, and it is sub-linear (Lan's u(n),
Cohere's 20.4 unique of 32 at 4 tokens). Papers assume drafting cost scales with nodes; here it does not.

N2. **Acceptance-point-agnostic level-1 drafting overlapped with the head** (item 13).

N3. **Workload-chosen draft vocabulary, rebuilt on the CPU from running token statistics plus every id in the current
prompt**, swapped in through `--mtp-draft-vocab` (same 40,960 rows, same bytes). The first-40,960-ids subset is why
some drafts can never be right; the prompt's own tokens are the most likely misses on copy-heavy work.

N4. **Rejected-draft recycling.** When the draft at position i is rejected, drafts i+1.. were conditioned on a wrong
token but often remain right (synonym and formatting substitutions). Keep them as free sibling candidates at the
next tree level (zero draft cost, one node of expert union each). Token Recycling does this from the target's top-k;
doing it from the engine's own discarded drafts is new.

N5. **Alternative-token PLE prefetch** (item 10): the n-gram rows for the drafter's and verify head's top-2 tokens are
fetched speculatively so the correction token after a rejection finds its rows cached. Only this model has a
per-step SSD read on the critical path, so no paper addresses it.

N6. **Bitwise GDN commit-in-prologue**: the sequential-replay variant of item 6. The next step's GDN kernel applies
the accepted prefix's buffered (k, v, alpha, beta) in the original order before processing the new window, so the
state is read once and written once per step and the per-position snapshots disappear, bitwise identical.

N7. **Lossless entropy-coded BF16 for the Gated Residual** (item 11) is new in this placement: the only BF16 tensors on
the critical path are the GR gates and router, and they are 19 % of bytes.

N8. **Dependency-aware task order inside a persistent layer kernel for this layer shape**: GR read -> norm ->
projections -> GDN/QSA -> GR write -> GR read -> norm -> router -> experts + shared -> combine -> GR write. The
router GEMV (2.6 MB) and the shared expert (3 x 1.6 MB) have no dependency on the routed experts; in a persistent
kernel their loads fill the routing bubble and the expert kernels' tail. Round 1 hides the shared expert on a side
stream already; the router and the next layer's W_d prefetch are the remaining fillers.

N9. **Measure first: window-size histogram and per-position acceptance.** `--window-hashes` already prints window
sizes; add per-position acceptance counts and per-window expert-union size to the stats. Items 1, 4, 5 and 9 are
tuned from these three numbers, and they tell within one run whether the suffix growth ever fires.

## 3. Unlikely to help here, and why

- **Expert prefetch/offload systems** (Pre-gated MoE, ProMoE, HOBBIT, MoE-Lightning, Fiddler, SpecPrefetch, APEX;
  AdapMoE, MoE-Infinity, EdgeMoE, SwapMoE were named in the brief but not opened). They hide a PCIe or SSD transfer
  into GPU memory. Here 99.5-99.9 % of expert reads already come from DRAM at full bandwidth, and the GPU reads
  the same LPDDR5 the CPU does; there is no slower tier to hide except the SSD (PLE and the 0.1-0.3 % misses, item
  10). Pre-gated and HOBBIT change routing or precision (lossy). MoE-Lightning and SpecMoE (Bang et al., 2026,
  https://arxiv.org/abs/2604.10152) are throughput systems for CPU-offloaded batches.
- **Large trees (Sequoia's and SpecExec's 20-100+ nodes).** They assume offloading, where a 100-token verify costs
  about the same as 1 token because PCIe dominates. Here every node adds ~0.6 GB of expert bytes; beyond ~8-10
  nodes the union cost exceeds the token gain (Cascade's 1.5x slowdown is this effect).
- **Lookahead / Jacobi decoding.** Exact, but it verifies an n-gram pool of many extra positions per step. Free on a
  dense model where FLOPs are spare; on this MoE each position is expert bytes.
- **PEARL-style draft/verify overlap** needs a second device or spare bandwidth; there is one bus. The single-device
  remnant that works is item 13.
- **Multi-request numbers.** Orinfer's 157 tok/s at 8 requests and 283 at 32, and the Thor thread's ~70 tok/s at
  2-3 streams, are aggregates. The verify window is this engine's batch.
- **Anything lower precision**: Orinfer's E8P ~2-bit experts (2.41 bpw overall), Thor's NVFP4 experts + FP8 dense,
  FP8 KV, Q8 hyper-connections, `--mtp-q4` for the drafter (changes drafts only, so technically lossless, but round
  1 showed drafter fidelity drives acceptance). The brief forbids them; they also explain most published numbers.
- **Early exit, layer skipping, approximate verification (near-tie acceptance), expert skipping**: lossy.
- **Head-row skipping with norm bounds** (skip lm_head rows outside the draft subset when a Cauchy-Schwarz bound
  proves they cannot win). The bound ||w_v|| ||h|| is 5-10x the real max logit; it would almost never fire.
- **CPU co-compute of GEMVs (Fiddler-style).** Same bus. It only adds throughput while the GPU is below the bus
  limit, which items 2-3 remove; and the CPU's ~30-40 GB/s is small. Use the CPU for suffix drafting, PLE prefetch
  and tree bookkeeping instead.
- **L2 persistence for weights**: 4 MB vs 6.5-8 GB per step.
- **Managed memory** (`cudaMallocManaged`) on Orin: `concurrentManagedAccess = 0`, so the driver flushes at every
  sync; pinned host memory is GPU-uncached. Keep hot data in `cudaMalloc` memory.
- **Clocks**: the SM already runs at ~1.29 GHz (MAXN); the EMC at its ceiling gives the 180 GB/s observed. Nothing
  lossless remains there.
- **Exhausted round-1 knobs** (do not retry): spec 3/5 with the current kernels, min-p 0.3, cache 15000, resident
  budget 1.5 GiB, VRAM_GY 4/16, DF_BRANCH side streams, the BF16 mmvf next-wave prefetch, IL kernels for 5-6 columns.

## 4. Search for a public > 60 tok/s report on this board

No public source reports > 60 tok/s single-stream for Qwen3.8-Flash-Next on a Jetson AGX Orin, and none at all for
an IQ3_S or other >= 3.3-bpw file. Found:

| Source | Board | Weights | Method | Single-stream decode |
| --- | --- | --- | --- | --- |
| Orinfer README and iMMIQ/manateelazycat model cards, measured 2026-10-21 (https://github.com/Term-inator/orinfer, https://huggingface.co/manateelazycat/Qwen3.8-Flash-Next-Orinfer-E8P-Q2A8, https://huggingface.co/immiq/Qwen3.8-Flash-Next-Orinfer-E8P-Q2A8) | AGX Orin 64 GB, CUDA 12.6 | E8P ~2-bit experts, Q4A8/W8 dense, BF16 HC; **2.414 bpw** overall | Rust + TileLang kernels, all experts resident, CUDA graphs decode-only, adaptive native MTP up to 3 drafts, int8 KV, 262,144 context | **56.35 tok/s** (512-token prompt, 257 output tokens); 157 tok/s at 8 requests; no quality numbers published |
| NVIDIA forum, Strata+Ninfer on Orin (https://forums.developer.nvidia.com/t/strata-ninfer-on-jetson-orin-with-qwen3-8-flash-next-jp6-2-jp7-x-soon/386806) | AGX Orin 32 GB, JP 6.2 | unstated | Strata port | ~20 tok/s at 32k, ~18 at 64k |
| This project's round 1 (notes.md, results.tsv on ar/decode-speed) | AGX Orin 64 GB | IQ3_S, 46.8 GiB experts | Strata, MTP spec 4 | 24.9 -> 34.4 tok/s |
| NVIDIA forum, Thor thread (https://forums.developer.nvidia.com/t/qwen3-8-flash-next-at-46-7-tok-s-on-jetson-agx-thor/383269) | AGX **Thor** 128 GB | NVFP4 experts + blockwise FP8 dense, BF16 KV | vLLM, 3 MTP drafts, 256K context | 34.8 -> 46.7 tok/s weighted; ~70 tok/s aggregate at 2-3 streams; not Orin |

Assessment of the "90 tok/s on the same board, no quality loss, same context" report: no trace of it in public
sources. The nearest real number is Orinfer's 56 tok/s with ~30 % fewer expert bytes than IQ3_S and no published
quality comparison. The claim most likely refers to one of: a ~2-bit build described as "no quality loss" on a small
eval; aggregate throughput over several requests; a short-prompt or copy-heavy workload where MTP acceptance and
suffix drafts run high; or a different scope (prefill, or decode excluding the first windows). Ask for the exact
file, prompt length, output length, concurrency and the measurement scope before treating it as a target.

## 5. Feasibility verdict for 90 tok/s, lossless, IQ3_S, 262,144 context

- **Not reachable by kernel work alone.** Even at the 204.8 GB/s peak, today's 6.5-8.3 GB/step at 2.45 tokens/step
  caps at 63-77 tok/s; at the 180 GB/s the board streams, 53-68 tok/s.
- **Not reachable by more tokens per step alone.** At today's ~100 GB/s average, 4 tokens/step over ~8.4 GB is
  84 ms/step = 48 tok/s.
- **Reachable only with both, at the edge**: ~4.0 accepted tokens per step (the Qwen report's own 4.06 with four MTP
  steps says the model allows it) **and** >= 90-95 % of peak DRAM bandwidth sustained across dense, HC, head, experts
  and drafts with no launch bubbles and no SSD stalls. That is 2.45 -> 4.0 tokens (1.63x) and ~100 -> ~185 GB/s
  (1.85x) at once. The best kernel today reaches 149 GB/s (73 % of peak); the best megakernels on big GPUs reach
  62-78 %. Treat 90 on general text as a stretch target with low odds; **55-70 tok/s is the defensible lossless
  goal**, and > 90 is realistic only in bursts on copy-heavy prompts through suffix drafting.
- **The combination, in order:** (1) item 1 drafter work (vocab file first, then FastMTP-style fine-tune of the MTP
  head, 4 drafts) with the window-size and per-position acceptance stats of N9; (2) items 2-3 as one GEMV-family
  rewrite that keeps GB/s to 8 columns and reaches >= 150 GB/s; (3) item 8 GR fusion and item 6/N6 GDN commit; (4)
  item 5 suffix/lookup flags once wider windows are cheap; (5) item 4 trees of ~8 nodes; (6) item 7 persistent
  layer kernels; (7) items 9-14 as polish. Expected landing: ~47 tok/s after (2), ~60 after (1)+(3), 65-75 after
  (4)-(6) on general text, higher on repetitive text.

## 6. Sources opened (all cited above)

Strata fork notes.md and results.tsv (ar/decode-speed); Strata README (Niko1221/Strata); NVIDIA forum Orin and Thor
threads; Orinfer README and two model cards; Qwen3.8-Next report arXiv 2608.30320 and Qwen/Qwen3.8-Flash-Next
config.json; Hyper-Connections 2409.19606; Gated DeltaNet 2412.06464; CUDA for Tegra app note; CUDA L2 cache control;
Lan 2610.34440; EcoSpec 2607.12696 (cost-aware draft selection on expert union, 1.62x on 671B/235B/120B MoEs; needs a
predictor, not used above); Cascade 2506.20675; SpecMoE 2604.10152; Cohere megakernel and MoE-SD blogs; Hazy "No
Bubbles"; MPK 2512.22219; FastMTP 2509.18362 and the Red Hat article; EAGLE-2 2406.16858; EAGLE-3 2503.01840;
SpecInfer 2305.09781; Sequoia 2402.12374; SpecExec 2406.02532; Lookahead 2402.02057; SuffixDecoding 2411.04975;
Token Recycling 2408.08696; prompt-lookup-decoding (GitHub); SpecDec++ 2405.19715; Medusa 2401.10774; PEARL
2408.11850; MARLIN 2408.11743; DFloat11 2504.11651; ZipNN 2411.05239; ReplaySSM (tridao.me, 2026); Pre-gated MoE
2308.12066; ProMoE 2410.22134; HOBBIT 2411.01433; Fiddler 2402.07033; MoE-Lightning 2411.11217; SpecPrefetch
2607.24787; APEX 2608.11688; DeepSeek-V3 2412.19437 (abstract only; MTP acceptance figures not on the page, so not
quoted).
