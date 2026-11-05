# Round 3 research ideas (briefs for the next agents; newest last)

## B3a: port upstream `STRATA_GU_SWIGLU=1` (iteration 1; built in iteration 5, commit 99f5d04c, runs e030-e032: notes.md)
- Upstream (read-only clone): `~/workspace/research-engines/Strata/src/kernels/cuda/iq_kernels.cu`
  `native_gu_swiglu_kernel` 2869-2943, launcher `launch_gu_swiglu` 4269-4292, dispatch in `native_expert_grouped`
  6376-6391 (it skips the gate/up launch and the SwiGLU launch when it ran).
- Ours (`~/workspace/strata-ar/src/kernels/cuda/iq_kernels.cu`): the 16-lane gate/up path is
  `native_gu_multi_kernel` SUB16 branch 1265-1321 (`xb == 80`, one 16-lane sub-warp a row, 16 rows a 256-thread
  block, gate rows 0..n_ff-1 then up rows; IQ3_S = TG 21 takes the `STRATA_EXP_PF` L2-prefetch variant, `launch_gu`
  2702-2724, `__launch_bounds__(256, 5)`); SwiGLU + q8_1 is `swiglu_q8_1_entries_kernel` 1581-1600, launched at
  3640-3646 (`sw_v1` false on CUDA).
- We have no `row_dot2_80_sub16` (upstream's gate and up rows in one call). Bitwise route: in the fused kernel each
  16-lane sub-warp calls our `row_dot_80_sub16` twice (gate row r, then up row r: same function, same lanes, same
  floats as the two rows of the multi kernel), lane c keeps entry c's sums (as `lane_pick`), forms
  `__fmul_rn(g / (1.0f + __expf(-g)), u)` (the SwiGLU kernel's exact expression), writes `sh[c][sw]`, sync, warp k
  `q8_1_store(sh[k][lane], hq, (e + k) * n_ff + blockIdx.x * 32 + lane)`. 512 threads = 32 sub-warps = 32 hidden
  columns, so a block owns one q8_1 block per entry. Carry `STRATA_EXP_PF` (prefetch the block's 32 gate rows and 32
  up rows of the next group) or measure without it first.
- Before coding, confirm decode reaches this path: `STRATA_EXP_LAYOUTS` / `em0` on the CUDA build, `g_exp_phase == 0`,
  not `v1`, and the IQ3_S pack's gu type is 21 with `n_embd` 2560 (round 2 notes call it the `kSplit` path).
- Expected 0.5-1 ms a T4 window (48 MoE layers: one launch and the gate/up float round trip each), ~+1%. Confirm in a
  `STRATA_VERIFY_PROFILE` run: the experts gate/up+SwiGLU row at T4 down >= 0.3 ms; texts 1.0 on all nine. Kill:
  < 0.1 ms or a texts change (the math must be the same calls; a change means an ordering slip, not noise).

## B8: prompt-informed expert placement (placement only; adaptive tier stays off) (built in iteration 10: commit 7aa743b5, runs e055-e060, notes.md)
- After prefill, count the prompt's routing per (layer, expert), swap the top non-resident ones into the cache slots of
  the least-used resident ones (the adaptive tier's swap machinery: generate.cpp ~7861-7935 `pending` / `apply_pending`,
  `adapt()`; `drive.d.usage` is the per-(layer, expert) counter it already keeps).
- **It changes texts by construction**: a CPU-miss expert and a GPU-hit expert do not give bitwise-equal results
  (evidence: `ok_slots_drift` runs and the mixed profile, agreement 0.023 at 19,112 vs 19,068 slots). So every
  placement change is REVIEW, never PASS, against the current gate, unless the CPU miss path is made bitwise equal
  to the GPU path (a larger item that would also make every cache-size drift harmless).
- Value: prose/repetition (77-90% hits -> each 0.1% hit rate ~3% decode, profile finding) and possibly review's last
  0.1% of misses (~1.5-2.4 misses a window, ~2-3 ms, round 2 e028).
- **Iteration 9 design: "prompt-informed refill" (`STRATA_PROMPT_REFILL=1`, M, ~80-120 lines, no blocking rounds).**
  Every request already lends the top ~1,780 cache slots (3.41 GiB, the profile's lowest-ranked pairs) to the
  prompt path and refills them after prefill from the mapping (generate.cpp serve path: `lend` ~10257 marks the
  owners `kNotResident` and records `p.lent` = (pair, slot); `refill_issue` ~10198 copies each owner back into its
  slot with `fill_slot_queued` and restores `host_res`; `refill` ~10231 then `res_upload()`). B8 changes only
  *which* pair goes into each lent slot: the prompt's most-routed non-resident pairs instead of the owners. The
  copies cost the same (one blob per lent slot), and the prompt's routed experts were just streamed by prefill, so
  they are likely page-cache hits (faster refill than today's owners).
  1. Count: prefill.cpp host-group path (~3024-3074: `ids_h` = this layer's T x K routing ids on the host after
     `cudaStreamSynchronize(m.cs)`). Add a `float* prompt_usage_` member to `Prefill` (setter, default null);
     there, `if (prompt_usage_) for i < T*K: if (0 <= ids_h[i] < n_expert) prompt_usage_[l * n_expert + ids_h[i]]
     += 1`. Confirm this branch is the bench's (the fused branch prints `prompt experts on the fused int8 kernels`;
     f1's engine.log has no such line, so likely yes): print the total count once per request.
  2. Choose (in `refill_issue`, single participant first; skip for layer splits): candidates = every pair with
     `host_res < 0` and prompt count >= 2, plus the lent owners (count as they are). Rank by prompt count, ties by
     profile rank (lower = hotter; `rank` as kvg builds it at ~6385). Walk the lent slots and give each the best
     remaining candidate whose blob fits: `xcache.slot_offset(s + 1) - xcache.slot_offset(s) >= blob_bytes(layer)`
     (the check kvg uses at ~6400). Replace an owner only if the candidate's count >= the owner's + 2 (the
     adaptive tier's margin, ~8194). Keep `p.lent[k] = (new pair, slot)` so `refill_wait` and later loans stay
     consistent; owners not refilled stay `kNotResident`.
  3. Invariants: no pair in two slots (`host_res[new] < 0` before, set to the slot after); kvg (~6383) and the
     adaptive tier (`a_res = host_res`, ~8331) both derive slot owners from `host_res`, so they stay correct. With
     A6 on, drain the adaptive round before `lend` (check that the serve loop already does). Print one line per
     request: `prompt refill: N of M lent slots took prompt experts (counts a..b)`.
  - Texts: REVIEW class (placement). Expected: repetition and prose hits up sharply from request 1 (A6 needed ~3
    requests to reach 99%: e014), review's tail misses down. Judge like A8 (iteration 9 table): two runs at equal
    slots must give identical texts (the refill is deterministic given the prompt), then speed vs the A8/A6 runs.
  - Stacks with A8 (bigger cache) and A6 (the tier keeps adapting during decode).

## B9: a faster miss path at the same placement (texts stay identical: PASS-capable on prose/repetition)
- For a fixed profile and slot count the set of CPU-miss experts is fixed; reading their blobs faster (more I/O
  depth, zero-copy from page-cache pages, earlier issue) changes only timing, and the CPU kernels stay the same, so
  the nine texts stay identical. This is the only prose/repetition lever the current gate can call PASS (B8 and the
  adaptive tier change texts).
- Size of the prize: repetition reads ~13.9 GB from storage per request for 46.4 GB of expert reads (plan-review
  item 2) and runs at ~15 tok/s; round 2 measured the review miss path as I/O (`jobs` = the 2.33 MB blob fetch,
  generate.cpp per-layer host line; e028).
- Upstream: `STRATA_COLD_OVERLAP=4` (zero-copy compute straight from the mapping when pages are cached) and
  `STRATA_IO_PF_GATE` (upstream-strata.md 3.9: RTX 3060 at 20-50% misses 1.14-1.47x). First experiment: a
  `STRATA_DECODE_TIMING` run on prose/repetition to split the window into `jobs` (fetch) vs `CPU` (compute) vs GPU
  (r3-e001 has this line per request); if `jobs` dominates, port the zero-copy path / raise I/O depth.
- **Measured (r3-e001, repetition): `jobs` 91-105 ms + `CPU` 101-112 ms of a 258-284 ms window; GPU ~51 ms.**
- Code read (iteration 1): per layer, the `jobs` stamp (`expert_source.cpp` c2 3547 .. c3 3622) covers
  `d.src->prefetch(layer, misses)` (3571) and then a serial host-thread loop calling `d.src->blob(layer, e)` per
  CPU-miss expert (3597-3621); the `CPU` stamp is `pool->run_split_multi_native` over all jobs (3625).
  With `STRATA_IO_PREFETCH` on the experts.bin pack, `io_fill_` is true by default (589-592; `STRATA_IO_PF_STAGE=1`
  turns staging on): `prefetch()` (1312-1327) runs a mincore `cached_bytes` check per missed blob and enqueues the
  uncached ones to the I/O workers, and `io_blob()` (707-716) hands out the mapping at once (zero-copy, so upstream's
  COLD_OVERLAP is ours in effect). **So the kernels in `CPU` may be waiting on page faults for blobs the workers
  have not read yet, and what fills `jobs` (91-105 ms) is not settled by reading** (mincore checks, the hit rows'
  memsets, lock waits?). Measure before coding: `--pool-workers` moving `CPU` says compute; `STRATA_IO_PF_THREADS`
  moving it says page waits; a `STRATA_IO_PF_STAGE=1` run says whether staging beats faulting.
- Two lossless steps, both same bytes / same kernels / same rows per task:
  1. settings: `--pool-workers 11` (and 7) for `CPU`; `STRATA_IO_PF_THREADS` 16 for `jobs` (more reads in flight).
  2. code: overlap the two phases: hand each job to the pool as its blob lands (or let pool workers call `blob()`
     themselves, in parallel), so a layer's compute runs under its remaining reads. The pool splits by output rows
     with each row whole in one task (round 2, pool.cpp:630), so order of completion cannot change a result.
- **Correction (iteration 2, code + r3-e001 engine.log): the base does NOT take the `io_fill_` path above.** engine.log
  line 16: "experts via mmap (--mmap-experts; the GGUF shards in place, no experts.bin)", so `role_ptr_` is set and
  `io_fill_` is false (expert_source.cpp:591) whatever `STRATA_IO_PF_STAGE` says: **r3-e013-iostage is a no-op = a
  repeat of e001** (use it as e001's spread). The real path: `prefetch()` (1312) skips the io_fill_ branch, claims a
  stage buffer per missed blob and calls `fill_many` (1405-1467), which **spawns min(n, 8) std::threads per layer**
  (`STRATA_FETCH_THREADS`, generate.cpp:4597) that each run `copy_from_files` (1111-1156): an exact mincore per span,
  then pread (uncached span) or memcpy (cached span) of the 3 role slices into the stage buffer. The decode thread
  joins them, then builds jobs from the staged blobs, then `run_split_multi_native` (pool.cpp:766). Stage buffers age
  out after kStageAge = 3 layers or 256 assemblies (expert_source.hpp:720), so nothing is reused across windows.
- Repetition per request (e001 engine.log:126-132): 5.45 CPU-miss experts a layer-window, ~262 blobs a window (~700 MB
  assembled, 70% memcpy from the page cache, ~215 MB a window from the SSD); 13.9 GB from storage a request. During
  `jobs` the demand reads run at ~1.8 GB/s (11.8 GB in ~6.7 s); inferred from these totals (not measured per phase),
  the SSD idles during `CPU` except for the look-ahead's read-ahead (784 read ahead, only 122 used: ~2 GB of wasted reads a request competing with demand reads).
- **B9 step 2, concrete (`STRATA_MISS_OVERLAP=1`, opt-in, ~80 lines in expert_source.cpp around 3548-3627):**
  1. Split the layer's `miss` list by `cached_bytes(layer, e, total, false) >= total` (the sampled probe).
  2. Hand the uncached ones' `fill_stage` to a background thread (or a persistent fetch pool: today's per-layer
     thread spawn costs ~240 creates a repetition window, a few ms) and fill the cached ones on the decode thread +
     helpers as today.
  3. Build jobs for the ready blobs and run `run_split_multi_native` on them; then wait for the uncached fills, build
     the rest and run the pool again. Batching is already split by `kMaxSplitMulti` (pool.cpp:769-791): an expert's
     gate/up rows, its q8 quant per (expert, token) and its down rows never read another expert's data, and each entry
     writes its own `out` row (`out + i*H`), so two batches give the same bits as one. Check `job_of` / `jobs_multi`
     indexing (3598-3614) when building jobs in two passes, and that `d.ms_jobs` / `ms_pool` still stamp sensibly.
  - Expected (repetition, per layer): today jobs ~2.0 + CPU ~2.2 ms; overlapped ~0.4 (memcpy) + max(SSD ~1.6, CPU
    of the cached ~1.5) + CPU of the uncached ~0.7 = ~2.7 ms: **-70 ms of a ~260 ms window, rep ~+35%**; prose
    ~-15 ms of ~120 (+12%); review ~0 (0.03-0.05 misses a layer-window). Texts must stay 1.0 on all nine (same
    blobs, same kernels, same rows): PASS-capable. Kill: texts change (a job-building slip) or rep < +10%.
  - Cheap side item: `STRATA_IO_PREFETCH`'s look-ahead read-ahead is 85% unused on repetition (736/858); once the
    overlap lands, measure `STRATA_IO_PF_THREADS=2` (fewer wasted reads beside the demand reads).

## A6b: the adaptive tier's round off the critical path (iteration 4; only if e023/e024 point here)
- r3-e014 (`--adapt-every 16`) lifts prose 17.4 -> 27.4 and repetition 15.5 -> 31.4 but review's same-text request
  1 ran 24.0 vs 34.0 (notes.md iteration 4). A blocking round (generate.cpp `adapt()` 7964-8100, started on a thread
  after the window at 11580 and joined at 11661 after the draft) calls `srcp->blob_stable(layer, in)` for up to 96
  non-resident experts (mmap tier: assembled from the 3 GGUF slices, maybe SSD-cold) and queues their H2D copies;
  the next window then waits for them (`apply_pending(true)`, `adapt_lag` 1, 11505-11506). The join and the wait
  fall outside the decode-timing terms (dt_run/commit/draft), so a run shows them only as wall time.
- Options, in order: (1) `STRATA_ADAPT_LAG=2` (queued as e024: settings only); (2) start the round's blob reads on
  the io prefetch workers one round early (the chosen swaps are known after `adapt()`'s choose step) and do the
  copies at the next round; (3) `--adapt-accepted-only` (counts only published rows, fewer spurious candidates).
  Each keeps the swap set and the window a swap lands in a function of the window count (deterministic texts).

## B4 note: expert kernel bandwidth (iteration 4, from r3-e008's per-stage table)
- **Correction (iteration 5): real sizes are gate + up 1.408 MB and down 0.92 MB an expert** (IQ3_S 110 B / 256,
  IQ4_NL 18 B / 32). Down runs ~144 GB/s, gate/up ~20% slower per byte (bytes 1.53 : 1, time 17.0 : 9.2). The
  gate/up-specific gap is ~3 ms a T4 window. Not the grid lookups: round 1 e036 staged the IQ3_S grid in shared
  memory (bitwise, -0.3%, inside the spread; strata-ar-lab/notes.md:382). Round 1 p037: one load in flight per
  thread streams 101 / 135 / 167 GB/s at 2 / 4 / 6 blocks of 256 a SM, 4-8 in flight 172-180: so **loads in flight
  per SM** is the lever (`Split<21>::load` reads 5 small fields of one 110-B block per item (qs 8 B, qh, signs 4 B,
  scale, d), 3 + 2 items per lane, each followed by 8 grid gathers and a dp4a chain per column). GU_SWIGLU's `row_dot2` doubles that per thread (two rows); if e031 shows the row
  dropping more than the SwiGLU launch (~0.3-0.5 ms), the next step is 4 rows per sub-warp (gate/up of 2 columns).
- Review T4 window 82 ms: VRAM-hit gate/up+SwiGLU 17.0 ms, down 9.2 ms (T1 6.4 / 3.6). ~30 distinct experts a
  layer-window x 48 layers; at an estimated ~1.5 MB of gate/up and ~0.75 MB of down an expert that is ~125 and
  ~117 GB/s vs ~180 GB/s measured streaming (CONTEXT.md). Check the real sizes (`expert_layout()` gu_row x n_ff
  x 2, down) and time gate/up alone (a probe like round 2's `STRATA_BW_PROBE`) before coding: if they are at ~65%
  of streaming, gate/up rows per wave / EXPDEC (plan B4) is worth up to ~5-8 ms a T4 window, more than B3a's ~1 ms.

## B10: QSA decode attention is latency-bound with a ~0.6 ms-a-column slope (iteration 14, read only; L item)
- Measured (r3-e038 `STRATA_VERIFY_PROFILE`, review at ~4.3K context; round 2 saw the same 0.89/1.51/2.14/2.69):
  `attention` T1 0.88, T2 1.52, T3 2.15, **T4 2.73 ms a window** (12 QSA layers), `scores+topk` 0.5-0.65 flat.
- Kernel (base runs `STRATA_ATTN_PRE75=1` = PR #540's `attn_chunk_kernel_pre75`, NC 2, 4 V loads in flight; round 1
  e077): grid (n_chunks, n_head_kv 2, n_q), CHUNK 64 cells, HD 256, G 12 query heads a KV head. Selection width
  = `idx_top_k + idx_block - 1` = ~2,051 cells once the context passes it, so 32 full chunks + 1 of 3 cells = 66
  blocks a column; round 1 put the pre75 kernel at 4 blocks of 256 a SM = 64 resident. T4 = 264 blocks = ~4
  waves of ~50 us a layer: time is waves x block latency, linear in columns.
- Bytes: K + V int8 = 2 x 256 B a cell a KV head; ~2,051 cells x 2 heads x 512 B = 2.1 MB a column a layer, x 12
  layers x 4 columns = ~100 MB a T4 window = 0.65 ms at 150 GB/s vs 2.73 measured (~37 GB/s). Compute ~0.4M FMA a
  block, ~10 us a wave at full rate. So ~2 ms of a T4 window (~2.4%) and ~0.6 ms of a T1 window are latency.
- Columns do not share loads: each column has its own selection (sel_ + t * cap), and adjacent columns' top blocks
  overlap but are not equal, so a multi-query block cannot just reuse one K/V read. The chunk partition (64) feeds
  the merge's sum order, so changing CHUNK is not bitwise. A bitwise speedup has to keep, per column: the per-lane
  8-dimension partials and the reduce order of each score, the per-chunk max / exp-sum, the ascending fold of V per
  chunk, and the merge order over chunks. Candidates: more loads in flight per thread in the score phase (all of a
  warp's 8 cells' K rows issued before the first reduce), a 2-chunk-per-block variant at T >= 2 that keeps each
  chunk's math separate but halves blocks (fewer waves only if occupancy holds), or the K/V gather of block c+1
  under block c's math (cp.async). Measure first: `STRATA_BW_PROBE=1` prints the pre75 kernel's registers and
  blocks a SM (round 1 saw 4); a probe at n_q 1..8 in isolation would settle waves vs latency.
- Expected <= ~1.5-2% on review (attention is 2.7 of ~81 ms at T4), more at longer contexts only if the selection
  width grows (it does not past ~2K cells: width is capped), so this stays a ~2% item. Below B7/B10-class
  scheduling items in value per effort.

## B12: multi-token NEON kernels for the CPU miss experts (iteration C3; gate/up built as 9135446b, runs e092-e094)
- On the Orin the miss pool runs ggml-cpu's one-token `vec_dot` per (row, token) (`native_gu_rows` /
  `native_down_rows` fallbacks in native_expert.cpp; the x86 builds have multi-token kernels). Expert groups hold
  1.37 (prose) to 1.73 (repetition) tokens on average, and the CPU part is 27-37 ms of a ~100 ms prose/repetition
  window, so decoding each block once per group is the prose/repetition lever that keeps texts identical.
- Gate/up IQ3_S (`STRATA_IQ3S_NEON_MT`, 9135446b): ggml's NEON body with the token loop inside; the only float step
  is `sumf += d*(sumi1 + sumi2)` a 256-block (mode 1 fma, mode 2 mul+add; e092/e093 decide).
- **Down IQ4_NL, if the gate/up kernel pays** (`ggml_vec_dot_iq4_nl_q8_0`, llama.cpp ggml-cpu/arch/arm/quants.c:
  4199-4257; n_ff 640 = 20 blocks, even, so the scalar tail never runs): per block pair the decode is 2 `vqtbl1q_s8`
  of `kvalues_iq4nl` + and/shift (cheap: expect a smaller gain than gate/up), then per token 2 x 2 `vdotq_s32` and
  `sumf += FP16(x0.d)*FP16(y0.d)*vaddvq(prod_1) + FP16(x1.d)*FP16(y1.d)*vaddvq(prod_2)`. Contraction choices for
  that line under GCC -ffp-contract=fast (statement order X=A*B, t1=X*C, Y=D*E, t2=Y*F, t3=t1+t2, sumf+t3): most
  likely `sumf + fma(X, C, Y*F)`; also try `sumf + (X*C + Y*F)` (no contraction) and `sumf + fma(Y, F, X*C)`. Each
  as a mode of one switch, one build, the gate picks. Q8_0 activations: `block_q8_0` (fp16 d + 32 int8).
  Size (instruction count, not measured): a 64-weight pair decodes in ~10 ops vs ~18 a token for loads, 4 sdot,
  2 addv and the float line, so nt=2 saves ~18% of down time; over the group mix ~10% of down, ~1% of a repetition
  window. Low priority: do it only if e092/e093 show the CPU part still dominates after the gate/up kernel.
- LM head (for the review side, measured r3-e038 profile): native Q5_K head 521 MB, T1 3.43 ms (~152 GB/s, at the
  streaming rate), T2 3.75, T3 4.54, **T4 4.78**, T6 11.27 ms. So <= ~1.3 ms a T4 window (~1.6% review) of room in
  the head's column slope: a B1-class item, not a quick one.

## B13: CPU misses computed by the GPU with the CPU's exact rounding (iteration C4; feasibility probe r3-e095)
- Today a GPU-computed miss rounds like the GPU kernels (q8_1 activations, dp4a, warp sums), not like ggml-cpu
  (Q8_K / Q8_0 activations, per-block float accumulate in block order), so moving misses to the GPU changes texts
  (REVIEW class: A6, the cache-size runs, the PCIe share). Another project on the board measured ~180 GB/s GPU reads from
  cudaHostRegister'ed / cudaHostAlloc-mapped memory on this board, so the GPU could read miss blobs in place.
- Idea: GPU kernels that are bit-for-bit ggml-cpu's arithmetic: quantize x to Q8_K exactly as quantize_row_q8_K_ref
  (amax with first-max tie rule, iscale = -127/max, magic-bias nearest int, bsums); per row and block the integer
  sums (exact in any order), then the float steps in ggml's order with explicit `__fmaf_rn` / `__fmul_rn` +
  `__fadd_rn` (no contraction freedom); SiLU with a port of glibc's expf (double arithmetic, the 32-entry table,
  explicit fma or not); Q8_0 of h as arm quantize_row_q8_0 (`__fdiv_rn`, `__float2int_rn`, `__float2half_rn`); the
  IQ4_NL pair line in the right form. The rows land in h_ymiss_ exactly as the pool writes them, so the combine and
  every later step are unchanged: texts identical by construction once each piece is proven.
- Measured size (r3-e092 timing, repetition at pool 9 SIBLINGS + the NEON gate/up kernel): 5.5-5.6 CPU experts a
  layer-window = ~265 expert computations x 2.33 MB = ~620 MB of weights a window through the CPU in `CPU` 47-58
  ms (~11-13 GB/s over 9 A78AE cores), of 124-170 ms windows; prose 1.8-2.7 CPU experts, `CPU` 14-20 ms of ~80 ms.
  The same bytes at ~150 GB/s on the GPU are ~4 ms: repetition windows could drop by ~40-50 ms (~+35-45%), prose
  by ~12-16 ms (~+15-20%), all with texts identical if the replicas are exact.
- Why it could pay: prose/repetition windows spend 27-37 ms in CPU compute (C3) plus file-tier waits (C4). The GPU
  at ~150 GB/s on ~2-6 miss experts a layer-window (2.33 MB each) is ~1.5-4.5 ms a window if the bytes are page-
  locked RAM (B14) and the kernels are not issue-bound like the hit kernels (they will be: scalar-exact float steps
  per block, but only 10 IQ3_S / 20 IQ4_NL blocks a row).
- Risks: the replicas must match every miss (one wrong bit changes text); glibc's expf is not correctly rounded,
  so it must be the same algorithm, not a better one; whether the Orin's GPU can read pageable mmap pages directly
  is not verified (B14's page-locked copy or a registered region avoids the question).
- Where it plugs in (read, not built): verify.cpp `post()` already runs a GPU share of the misses, the "PCIe" groups
  (`grouped(p_ptr2, p_start2, p_counts + 2, kPcieGroupRows, hit_out)`, off in the base via `STRATA_NO_PCIE=1`), into
  `hit_out`, and `moe_hit_add` / `STRATA_HIT_COMBINE` place every row at its (token, k) slot before the combine, so
  the sum order does not depend on who computed a row (GPU rows enter as `0.0f + hit`: a -0.0 row becomes +0.0,
  harmless unless a whole sum is zero). The replica kernels would replace `grouped()` for those groups, reading x
  (fp32, the same bits the host copies to h_x_) and the blob pointers the plan already gives.
- Step 0 (queued as r3-e095, commit bec4857c): the CPU replicas counted against ggml in the live engine
  (`STRATA_MISS_REPLICA_CHECK=1`). Step 1: the CUDA replica kernels behind a switch, run beside the CPU for one layer
  with a bit compare logged. Step 2: route the misses whose blobs are in B14's copy to them. Multi-iteration (L).
- **C5 (commit b6f4b116, run r3-e100): steps 1 and 2 in one, without the side-by-side compare.** The replica kernels
  (src/kernels/cuda/miss_exact.cu, `STRATA_MISS_GPU_EXACT=1`, forms `STRATA_MISS_GPU_FORMS`, default 1110) replace
  the PCIe share's kernels; with `STRATA_NO_PCIE=0 --pcie-frac 1 --resident-budget-gib 4` every miss in the RAM copy
  (<= 16 a layer) runs there. The served texts gate is the check (e093 showed it catches a single float-step change).
  If texts change and e095's forms do not fix it, build the compare: run the replica for the CPU's own misses into a
  side buffer and count unequal floats per kernel (q8k bytes, h q8_0 bytes, down rows).
- **Step 0 result (r3-e095, C9): every piece has a 100% bit-equal form, and it is the default `1110`.** Over one
  bench (texts 1.0 on all nine): q8_K(x) rows 59,081 fused 100% (split 99.6%); iq3_s dots 33.6 M fma 100% (mul+add
  48%); expf 16.8 M fma and split cubic both 100%; q8_0(h) 122,369 rows 100%; iq4_nl dots 254 M fma(X,C,Y*F) 100%
  (others 60% / 53%). The CPU replicas therefore are ggml's arithmetic; what is left unproven is only the CUDA port
  of them (e100 texts, e101's float compare). Quirk: the first report line (engine.log:44) shows expf 42 with 84
  bit-equal (a counter read before its total; later lines agree), not a correctness issue.
- **C12 (r3-e109): texts changed because the model mixes expert types** (layer 0's gate/up are IQ3_XXS, type 18;
  the replica covers IQ3_S/IQ4_NL only, and the planner still put that layer's misses in the PCIe share, which then
  ran the GPU kernels). Fix 3fa70777: uncovered layers keep CPU misses (run r3-e114). An IQ3_XXS replica (ggml's
  NEON ggml_vec_dot_iq3_xxs_q8_K: grid iq3xxs_grid, signs via ksigns_iq2xs, scale `0.5f + (aux32 >> 28)`, final
  `0.25f * sumf`; prove it with a CPU replica count first, as e095 did for IQ3_S) would cover the rest. Memory: with
  the PCIe share on, e109 lost ~2 GiB of MemAvailable beyond the copy's 1.46x (ready 7,011 vs 12,752 MiB), so under
  the 6 GiB floor the copy is capped near ~1.5-2 GiB until that is found.
- Reach limit: only misses in the RAM copy are GPU-readable (Orin has no pageable-memory GPU access; a memcpy into
  pinned memory per miss costs more than the CPU compute). So B13's gain is capped by B14's copy hit rate on
  prose/repetition misses (e097/e099 measure it).
- **C7 (16:20, written, not built): faster loads for the replica, only if e100/e104 show the share is slow.** The
  default `--pcie-mode auto` (2) copies each blob (2.33 MB) into device staging with a copy kernel, then the replica
  reads it again: ~3x the bytes of reading it once (all one DRAM on the Orin). `--pcie-mode direct` (1) needs no
  rebuild (expert_source.cpp:3500 gives the replica `device_alias()` pointers; verify.cpp:2365 skips the copy) =
  `overrides/r3-e104-gpuexact-direct.json`. Risk: mx_gu_kernel / mx_down_kernel read 1-byte loads (qs 8, signs 4,
  qh 1, scale 1 per sub-block; IQ4_NL 16 per block); from host-mapped pages these may not be cached in L1, so
  direct could be slower. The fix if so (bitwise the same arithmetic, only where bytes come from): each warp first
  copies its row into shared memory with 16-byte loads (`off = addr & 15`, `n = (bytes + off + 15) >> 4` uint4,
  lanes stride 32; a row is 1,100 B gate/up (<= 70 uint4) or 360 B down (<= 24); an aligned 16-byte chunk never
  crosses a page, so reading its slack bytes is safe), `__syncwarp()` before and after (the warp reuses the buffer
  for gate then up), then `mx_iq3s_row(s_row + off, ...)` and the IQ4_NL decode read shared memory. ~25 lines, 9 KB
  shared a block; put it behind `STRATA_MISS_GPU_STAGE=1` so the same exe A/Bs it (texts must be identical between
  the two by construction).

## B14: page-locked RAM copy of the non-GPU experts (iteration C4; runs r3-e096 / r3-e097)
- `--resident-budget-gib N` / `--resident-experts` already exist (generate.cpp:2220-2240, 6557-6640; never run in
  rounds 1-3). The copy is the file's bytes, built after the GPU cache, so slots and texts should not change; the
  CPU computes misses from RAM instead of waiting for SSD reads (`decode waited` 1.7-2.7 s a prose/repetition
  request in e090). Limits: the harness's 6 GiB MemAvailable floor (run_control.py). **Measured (C12): admission
  MemAvailable drops 1.46x the copy** (e096 4.77 GiB -> 4.82, e097 4.00 GiB -> 5.96, both `pressure_abort`, from
  e094's 11.79), so the usable budget is <= ~3.75 GiB (2.5 -> ~8.1, 3.5 -> ~6.7); the extra 0.46x is not in the
  engine's copy code (the copied file pages are left to the OS cache; exchange buffers ~0.25 GiB); the copy holds the experts the *review* profile ranks hottest, which may not be the
  ones prose/repetition miss. If e097 pays, a ranking from prose/repetition routing (a second profile, or the
  adaptive tier's counters) is the code follow-up.

## B15 (closed, iteration C10): B1's per-column dense slope under the bitwise rule; tensor-core GEMVs
- The pinned mmvq expressions round per integer group (Q6_K 4 weights, Q4_K/Q5_K 8, IQ4_XS 32; native_mmvq.cu
  :644 / :539 / :187 / :1413), so the per-column work of a bitwise kernel is one int multiply + conversion + FMA per
  group in the pinned order, whatever forms the integer dot. Int8 `mma.m16n8k16` would use 4/16 or 8/16 of its k
  and needs a C-fragment remap to the pinned lane order (4 virtual-warp sums, then the xor tree = a bit-reversed
  binary tree over lanes); dp4a already does a 4-group. No gain on K-quants (92% of dense bytes). The Q6_K IL path
  already skips I2F (`exact_i2f_22`); Q4_K/Q5_K's I2F is ~-0.2 ms a window (round 1 dropped it). Do not rebuild.
- What is left for review on dense is the fixed T1 part (~137 GB/s vs ~180, ~4-5 ms a window): a load-time byte
  re-layout with 16-byte loads ahead, same lane-to-chunk map and order (round 2 research-ideas.md item 3(c)). L item.

## B16 (round 4 brief, iteration C11): review's fixed cost by stage, measured, and the two byte re-layouts it points to
- **Measured, not guessed** (r3-e038 `STRATA_VERIFY_PROFILE`, review request 1, 101 windows; current kernels: IL,
  GU_SWIGLU, the base's switches; runs/r3-e038-gusw-prof/engine.log:61 has the full per-T table). Bytes from the
  same log's `native dense: types` line (engine.log:6; t14 Q6_K, t13 Q5_K, t12 Q4_K, t23 IQ4_XS, t20 IQ4_NL):

  | stage (n_out, matrices) | MB | T1 ms | T1 GB/s | T4 ms |
  | --- | --- | --- | --- | --- |
  | GDN qkv (10240, 36) | 709 | 5.45 | 130 | 7.54 |
  | GDN z (6144, 36) | 378 | 3.24 | 117 | 4.12 |
  | out-proj (2560, 48) | 594 | 4.67 | 127 | 5.79 |
  | QSA q (12288, 12; stage also holds q-idx: a lower bound) | 259 | 2.41 | 107 | 3.15 |
  | **big four, sum** | **1,939** | **15.77** | **123** | **20.60** |
  | shared expert + quant (640 x 96, 2560 x 48) | 143 | 2.82 | **51** | 4.57 |
  | head (Q5_K) | 521 | 3.43 | 152 | 4.78 |
  | VRAM-hit gate/up+SwiGLU (10 a layer at T1 = 480 x 1.408 MB) | 676 | 6.29 | **107** | 17.24 |
  | VRAM-hit down (480 x 0.92 MB) | 442 | 3.65 | 121 | 9.28 |

  (T1 window 48.81 ms profiled, T4 80.71. T4 expert rates: ~30 distinct hits a layer-window on average, so gate/up
  ~119 GB/s and down ~144 GB/s, lower bounds. The streaming ceiling on this board is ~172-180 GB/s with 4-8 loads in
  flight a thread; round 1 p037, another project on the board.)
- **Sizing at a 165 GB/s target, per window, holding today's per-column slopes:** big four -4.0 ms (15.77 -> 11.75),
  expert gate/up -2.2 ms at T1 / ~-4.8 at T4, down -1.0 / -1.2, shared expert ~-2 (it is latency-bound: ~3 small
  launches a layer at ~20 us each, not a byte problem). Review's mix is half T4 windows: **dense alone ~-4 ms of a
  ~77 ms window = ~+5% review (37.0 -> ~38.9)**, dense + gate/up ~+10-11%. These are the only review levers above
  the 0.5% spread left after C4/C8/C10 (B1b, N6, B2, B15 are closed or below it).
- **Why the dense rate is ~123 GB/s (code read, native_mmvq.cu):** Q6_K's 210-byte blocks are only 2-byte aligned,
  so `IlQ6K` / `Q6KTraits::load` (:1043-1058) read ql and qh through `load_int_b2` (two 16-bit loads an int), plus 2
  int8 scale loads and a half `d`: ~7 load instructions per lane per block, 4 blocks per lane per `m0` step, each
  step's 4 `v` iterations behind a `kbx < bpr` guard (so ptxas does not hoist the 4 blocks' loads together; at the
  64-register cap Q6_K NC4 R1 already needs 70). Little's law at 180 GB/s x ~0.6 us is ~6.8 KB in flight a SM; one
  210-B block a warp x 32 warps is ~6.7 KB: right at the edge, which fits ~120-130 GB/s.
- **Re-layout 1 (dense, bitwise by construction): lane-major 4-block groups.** Per row, for each group of 4 blocks
  (`m0 .. m0+3`, exactly what one lane's `v = 0..3` covers in native_mmvq_il_kernel), store: ql word `iqs` of the 4
  blocks contiguous (16 B per lane: one LDG.128), qh word `qh_word(iqs)` of the 4 blocks (16 B, lanes iqs and
  iqs+8 share it: same transaction), the 2 scale bytes `scales[so]`, `scales[so+4]` of the 4 blocks (8 B: LDG.64),
  the 4 `d` (8 B, warp broadcast). Same 840 bytes a group, so a row keeps its stride (2,100 / 5,040 / ... B); the
  tail group (n_in 2560 = 10 blocks -> 4, 4, 2) is the same form at 2 blocks (LDG.64s). 4 loads a lane per 4 blocks
  instead of ~28; the integers into each dp4a, the `q6_q8_dot_impl<true>` expression, `acc[v]` and the reduction are
  untouched, so outputs are bitwise those of today's IL kernel, and the T1 order is the same (IL's acc[v] = the T1
  kernel's warp v partial; that is why IL is already bitwise with native_q6_k_mmvq_kernel<false>), so one NC = 1..6
  kernel serves every window size.
  Plumbing that already exists: the `STRATA_Q6_PACKED` registry (`q6_packed_registry`, `native_q6_k_pack`,
  native_mmvq.cu:1843-2050; native_head.cpp:67 and mtp.cpp:844 register the heads) maps a weight pointer to a
  packed copy and `native_q6_k_mmvq` dispatches to it first (:2380). Add: a pack format flag, registration of the
  dense Q6_K matrices (native_dense.cpp), and the lookup inside `native_mmvq_il` (:2710, case 14) as well. Memory:
  a duplicate copy is 1.29 GiB for Q6_K (2.0 GiB for all four types), allocated after the expert cache is sized
  (`--expert-cache 14629` is an explicit cap, so slots stay 19,068); MemAvailable ~11.9 -> ~10.6 GiB, fine alone,
  too tight with B14's 4 GiB copy. Prefill keeps reading the GGUF copy (so prompt texts cannot move). Round 1's
  packed head (e006: planes, one 4-B load a thread, persistent 640 grid) was slower; the difference here is 16-byte
  loads with 4 in flight a lane and no persistent grid.
- **First experiments, cheapest first:** (1) no layout change: split the `m0` loop into a guard-free main part
  (all 4 blocks' `F::load` issued before any `apply`) + the guarded tail (round 1 idea (a), strata-ar-lab
  notes.md:1095); same order, so bitwise; check ptxas spills at NC 1-4 (`STRATA_BW_PROBE=1` prints registers and
  blocks a SM). (2) The layout above for Q6_K only (64% of dense bytes), checked bitwise and timed by
  `build/mmvq_il_parity --bench` (it already cycles weight copies past the L2) if the harness can run it, else by a
  load-time self-test like `STRATA_Q6P_SELFTEST`. (3) Q5_K / Q4_K / IQ4_XS the same way.
- **Re-layout 2 (expert gate/up, IQ3_S):** `Split<21>::load` (iq_kernels.cu:809-830) reads a 110-B block as 4 + 2
  16-bit loads (qs, signs) + qh/scales bytes + `d` = 9 loads for 15 bytes a lane, then 8 grid gathers. Rows are
  1,100 B (10 blocks, 4-byte aligned), so per row the planes qs 640 | qh 80 | signs 320 | scales 40 | d 20 are the
  same bytes, all 4-aligned: 5-6 loads a lane. Same integers, bitwise. Harder than dense: the slots are also read
  by the prefill expert kernels (prefill/moe_fused_iq.cu, moe_mmq.cu), and a duplicate of 19,068 slots is
  impossible, so it must be in place at slot-fill time with every GPU reader switched. Round 1 e039 (all 5 chunk
  loads hoisted: +5.5% slower, register pressure) says to watch occupancy. Do the dense one first.
