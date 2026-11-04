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
