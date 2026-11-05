// include/strata/kernels/miss_exact.hpp - ar B13 (opt-in STRATA_MISS_GPU_EXACT=1): the verify window's "PCIe share" of
// the CPU-miss experts (misses whose blobs sit in the page-locked RAM copy, --resident-budget-gib) computed on the GPU
// with ggml-cpu's aarch64 rounding, step for step, so a miss gives the same bits on either processor.  See
// src/kernels/cuda/miss_exact.cu for the steps and STRATA_MISS_GPU_FORMS.
#pragma once

#include "strata/kernels/iq_kernels.hpp"

#include <cstdint>
#include <string>

namespace strata::kernels {

/// STRATA_MISS_GPU_EXACT at startup (read once): 0 off, 1 the replica computes the PCIe share, 2 check mode (the CPU
/// computes those misses as without the switch, the replica computes them beside it into a side buffer, and
/// miss_exact_compare counts unequal floats: lines `strata miss_exact check:` on stdout).
int miss_exact_mode();
bool miss_exact_enabled();   // mode != 0
/// Check mode: the side buffer of token group `slot` (rows at ent_dst * n_embd), null otherwise.
float* miss_exact_side(int slot);
/// Check mode: the side rows of the PCIe groups' entries against `cpu_rows` (the CPU's rows, same indexing).
void miss_exact_compare(const int32_t* grp_start, const int32_t* n_groups, const int32_t* ent_dst, const float* cpu_rows,
                        int slot, int layer, void* stream);
/// Check mode: prints the totals (and the first unequal float, once) to stderr about every 2^20 floats compared;
/// called by the host's planner.  A no-op otherwise.
void miss_exact_report();
/// Uploads the expf table (glibc's 2^(i/32), rebuilt from exp2l); once, outside any stream capture.
bool miss_exact_init(std::string& err);
/// The replica kernels' layout: IQ3_S gate/up, IQ4_NL down, n_embd 2560, n_ff 640; at most 8 tokens and 80 entries
/// (`n_tok`, `n_entries`) and 2 token groups (`slot` 0/1).
bool miss_exact_supported(const NativeExpertLayout& L, int n_tok, int64_t n_entries, int slot);
/// native_expert_grouped's contract for the groups grp_ptr[0, *n_groups) (read on the device, so graph-safe):
/// out[ent_dst[e] * n_embd + r] for each group's entries, from `x` = the group's n_tok fp32 rows (the bits the host
/// copy of x holds).  `grid_groups` block rows stride over the groups.
void miss_exact_grouped(const NativeExpertLayout& L, const unsigned long long* grp_ptr, const int32_t* grp_start,
                        const int32_t* n_groups, const int32_t* ent_dst, const int32_t* ent_tok, const float* x,
                        int n_tok, int slot, float* out, void* stream, int grid_groups);

}  // namespace strata::kernels
