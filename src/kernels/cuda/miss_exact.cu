// src/kernels/cuda/miss_exact.cu - ar B13 (opt-in STRATA_MISS_GPU_EXACT=1): the verify window's "PCIe share" of the
// CPU-miss experts (misses whose blobs sit in the page-locked RAM copy) computed on the GPU with the CPU's exact
// rounding, so a miss gives the same bits whichever processor computes it and the texts do not change.
//
// Each step is ggml-cpu's aarch64 path (llama.cpp ggml-cpu/arch/arm/quants.c, ggml-quants.c) as the C4 replicas in
// native_expert.cpp model it (r3-e095 counts those replicas against the live engine):
//   1. Q8_K of x per token (quantize_row_q8_K_ref): amax with the first-maximum rule, iscale = -127/max, the
//      magic-bias round of iscale*x (fused or not), d = 1/iscale.
//   2. IQ3_S x Q8_K (ggml_vec_dot_iq3_s_q8_K): exact integer block sums, then per block in order
//      d = fp16(x.d) * y.d and sumf += d * (float) sum (fused multiply-add or not).
//   3. SiLU: (g / (1 + expf(-g))) * u with glibc's e_expf.c algorithm in double (its cubic fused or not).
//   4. Q8_0 of h (arm quantize_row_q8_0): d = amax/127, id = 1/d, nearest-even of h*id, d stored fp16.
//   5. IQ4_NL x Q8_0 (ggml_vec_dot_iq4_nl_q8_0): exact integer block sums, per block pair
//      sumf += X*C + Y*F in one of three contraction forms.
// Every float operation is an explicit _rn intrinsic (no contraction or fast-math flag can change it).  The forms the
// CPU build may have contracted are STRATA_MISS_GPU_FORMS = 4 digits: q8k fused (1/0), iq3s fma (1/0), expf fma cubic
// (1/0), iq4nl pair form (0 = fma(X,C,Y*F), 1 = X*C+Y*F, 2 = fma(Y,F,X*C)); default "1110".
#include "strata/kernels/miss_exact.hpp"

#include <cuda_fp16.h>
#include <cuda_runtime.h>

#define GGML_COMMON_DECL_CUDA
#define GGML_COMMON_IMPL_CUDA
#include "ggml-common.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace strata::kernels {
namespace {

constexpr int kEmbd = 2560, kFF = 640, kQK = 256, kNbX = kEmbd / kQK, kNbH = kFF / 32;
constexpr int kMaxTok = 8, kMaxEntries = 80, kSlots = 2;
constexpr int kIq3sBytes = 110, kIq4nlBytes = 18;   // block_iq3_s: d, qs[64], qh[8], signs[32], scales[4]; block_iq4_nl: d, qs[16]
static_assert(sizeof(block_iq3_s) == kIq3sBytes && sizeof(block_iq4_nl) == kIq4nlBytes, "ggml block layouts");

// per token group (slot): the Q8_K image of x and the Q8_0 image of each entry's h
__device__ __align__(16) int8_t g_xq[kSlots][kMaxTok][kEmbd];
__device__ float g_xd[kSlots][kMaxTok][kNbX];
__device__ __align__(16) int8_t g_hq[kSlots][kMaxEntries][kFF];
__device__ uint16_t g_hd[kSlots][kMaxEntries][kNbH];
__constant__ unsigned long long c_exp_tab[32];   // glibc __exp2f_data.tab: bits(2^(i/32)) - (i << 47)
// STRATA_MISS_GPU_EXACT=2 (check): the replica's rows go to h_side (kSlots x kMaxEntries x kEmbd floats, allocated at
// init in that mode only) and are compared with the CPU's rows of the same entries
// The totals reach the host through mapped memory (the server's stdout is its protocol: no device printf);
// miss_exact_report() prints them to stderr from the host's planner.
struct MxCheck { unsigned long long all, bad; int layer, entry, row, have; unsigned gpu, cpu; };
__device__ unsigned long long g_ck_all, g_ck_bad;
__device__ unsigned int g_ck_done, g_ck_first;
float* h_side = nullptr;
MxCheck* h_ck = nullptr;   // mapped host memory
MxCheck* d_ck = nullptr;   // its device alias

struct Forms { int q8k = 1, iq3s = 1, expf = 1, iq4nl = 0; };

Forms forms() {
    static const Forms f = [] {
        Forms r;
        const char* v = std::getenv("STRATA_MISS_GPU_FORMS");
        if (v != nullptr && std::strlen(v) >= 4) {
            r.q8k = v[0] == '1';
            r.iq3s = v[1] == '1';
            r.expf = v[2] == '1';
            r.iq4nl = v[3] >= '0' && v[3] <= '2' ? v[3] - '0' : 0;
        }
        return r;
    }();
    return f;
}

// 1. one 256-value block of one token per thread block
__global__ void __launch_bounds__(256) mx_q8k_kernel(const float* __restrict__ x, const int32_t* __restrict__ n_groups,
                                                     int slot, int fused) {
    if (*n_groups <= 0) return;
    const int b = blockIdx.x, t = blockIdx.y, j = threadIdx.x, lane = j & 31, w = j >> 5;
    __shared__ float s_m[8];
    __shared__ int s_i[8];
    __shared__ float s_v;
    const float v = x[(size_t) t * kEmbd + (size_t) b * kQK + j];
    const float ax = fabsf(v);
    float m = ax;
    for (int o = 16; o > 0; o >>= 1) m = fmaxf(m, __shfl_xor_sync(0xffffffffu, m, o));
    if (lane == 0) s_m[w] = m;
    __syncthreads();
    float amax = s_m[0];
    for (int k = 1; k < 8; ++k) amax = fmaxf(amax, s_m[k]);
    // ggml keeps the FIRST element of the largest magnitude (`if (ax > amax)`), sign included
    int idx = ax == amax ? j : kQK;
    for (int o = 16; o > 0; o >>= 1) idx = min(idx, __shfl_xor_sync(0xffffffffu, idx, o));
    if (lane == 0) s_i[w] = idx;
    __syncthreads();
    int first = s_i[0];
    for (int k = 1; k < 8; ++k) first = min(first, s_i[k]);
    if (j == first) s_v = v;
    __syncthreads();
    int8_t* q = &g_xq[slot][t][b * kQK];
    if (amax == 0.f) {
        q[j] = 0;
        if (j == 0) g_xd[slot][t][b] = 0.f;
        return;
    }
    const float iscale = __fdiv_rn(-127.f, s_v);
    const float val = fused ? __fmaf_rn(iscale, v, 12582912.f) : __fadd_rn(__fmul_rn(iscale, v), 12582912.f);
    const int iv = (int) (__float_as_uint(val) & 0x007fffffu) - 0x00400000;
    q[j] = (int8_t) min(127, iv);
    if (j == 0) g_xd[slot][t][b] = __fdiv_rn(1.f, iscale);
}

// 2. one IQ3_S row (n_embd 2560 = 10 blocks) for the group's nt tokens; every lane ends with the results.
// Lane l takes 32-weight sub-blocks p = l, l+32, l+64 (p < 80): block p/8, sub-block p%8, so a block's 8 sub-blocks
// are 8 adjacent lanes of one round and their integer sums add exactly.
__device__ __forceinline__ void mx_iq3s_row(const uint8_t* __restrict__ row, const int* s_tok, int nt, int slot,
                                            int fma_mode, int lane, float* res) {
    int acc[3][kMaxTok];
#pragma unroll
    for (int rd = 0; rd < 3; ++rd) {
#pragma unroll
        for (int t = 0; t < kMaxTok; ++t) acc[rd][t] = 0;
        const int p = lane + 32 * rd;
        if (p < kNbX * 8) {
            const int i = p >> 3, j = p & 7;
            const uint8_t* b = row + (size_t) i * kIq3sBytes;
            const uint8_t* qs = b + 2 + 8 * j;
            const uint32_t qh = b[66 + j];
            const uint8_t* sg = b + 74 + 4 * j;
            const int sc = 2 * ((b[106 + (j >> 1)] >> (4 * (j & 1))) & 0xf) + 1;
            int ws[8];
#pragma unroll
            for (int k = 0; k < 8; ++k) {   // weights 4k..4k+3: grid bytes, negated where the sign bit is set
                const uint32_t gv = iq3s_grid[qs[k] | (((qh >> k) & 1u) << 8)];
                const uint32_t sb = ((uint32_t) sg[k >> 1] >> (4 * (k & 1))) & 0xfu;
                const uint32_t m = ((sb * 0x00204081u) & 0x01010101u) * 0xffu;
                ws[k] = (int) __vsub4(gv ^ m, m);
            }
#pragma unroll
            for (int t = 0; t < kMaxTok; ++t) {
                if (t < nt) {
                    const int* q = reinterpret_cast<const int*>(&g_xq[slot][s_tok[t]][i * kQK + 32 * j]);
                    int s = 0;
#pragma unroll
                    for (int k = 0; k < 8; ++k) s = __dp4a(ws[k], q[k], s);
                    acc[rd][t] = s * sc;
                }
            }
        }
    }
#pragma unroll
    for (int rd = 0; rd < 3; ++rd) {
#pragma unroll
        for (int t = 0; t < kMaxTok; ++t) {
            if (t < nt) {   // nt is the same on every lane
#pragma unroll
                for (int o = 1; o < 8; o <<= 1) acc[rd][t] += __shfl_xor_sync(0xffffffffu, acc[rd][t], o);
            }
        }
    }
#pragma unroll
    for (int t = 0; t < kMaxTok; ++t) res[t] = 0.f;
#pragma unroll
    for (int i = 0; i < kNbX; ++i) {
        const float xd = __half2float(*reinterpret_cast<const __half*>(row + (size_t) i * kIq3sBytes));
#pragma unroll
        for (int t = 0; t < kMaxTok; ++t) {
            if (t < nt) {
                const int si = __shfl_sync(0xffffffffu, acc[i >> 2][t], 8 * (i & 3));
                const float d = __fmul_rn(xd, g_xd[slot][s_tok[t]][i]);
                const float s = __int2float_rn(si);
                res[t] = fma_mode ? __fmaf_rn(d, s, res[t]) : __fadd_rn(res[t], __fmul_rn(d, s));
            }
        }
    }
}

// 3. glibc sysdeps/ieee754/flt-32/e_expf.c (the ARM optimized-routines expf), as rep_expf in native_expert.cpp
__device__ float mx_expf(float x, int fused) {
    if (isnan(x)) return x + x;
    if (x > 0x1.62e42ep6f) return __int_as_float(0x7f800000);
    if (x < -0x1.9fe368p6f) return 0.f;
    constexpr double N = 32, InvLn2N = 0x1.71547652b82fep+0 * N;
    constexpr double C0 = 0x1.c6af84b912394p-5 / N / N / N, C1 = 0x1.ebfce50fac4f3p-3 / N / N,
                     C2 = 0x1.62e42ff0c52d6p-1 / N;
    const double z = __dmul_rn(InvLn2N, (double) x);
    const double kd = round(z);                                   // aarch64 frinta: ties away from zero
    const unsigned long long ki = (unsigned long long) __double2ll_rn(kd);   // = lround(z): kd is integral
    const double r = __dsub_rn(z, kd);
    const unsigned long long tb = c_exp_tab[ki % 32] + (ki << 47);
    const double s = __longlong_as_double((long long) tb);
    const double r2 = __dmul_rn(r, r);
    double y;
    if (fused) {
        const double p = __fma_rn(C0, r, C1);
        y = __fma_rn(C2, r, 1.0);
        y = __fma_rn(p, r2, y);
    } else {
        const double p = __dadd_rn(__dmul_rn(C0, r), C1);
        y = __dadd_rn(__dmul_rn(C2, r), 1.0);
        y = __dadd_rn(__dmul_rn(p, r2), y);
    }
    return __double2float_rn(__dmul_rn(y, s));
}

// 2-4. 32 rows (gate and up) of one group per thread block, then their SiLU values as one Q8_0 block per entry
__global__ void __launch_bounds__(256) mx_gu_kernel(size_t gu_row, size_t up_off, const unsigned long long* __restrict__ grp_ptr,
                                                    const int32_t* __restrict__ grp_start, const int32_t* __restrict__ n_groups,
                                                    const int32_t* __restrict__ ent_tok, int slot, int iq3s_fma, int exp_fma) {
    const int ng = *n_groups;
    const int chunk = blockIdx.x, lane = threadIdx.x & 31, w = threadIdx.x >> 5;
    __shared__ float s_h[kMaxTok][32];
    __shared__ int s_tok[kMaxTok];
    for (int q = blockIdx.y; q < ng; q += gridDim.y) {
        const int e0 = grp_start[q], nt = min(grp_start[q + 1] - e0, kMaxTok);
        const uint8_t* blob = (const uint8_t*) grp_ptr[q];
        __syncthreads();   // the previous group's readers of s_h / s_tok are done
        if (threadIdx.x < kMaxTok) s_tok[threadIdx.x] = (int) threadIdx.x < nt ? ent_tok[e0 + threadIdx.x] : 0;
        __syncthreads();
        for (int rr = 0; rr < 4; ++rr) {
            const int rl = w * 4 + rr, r = chunk * 32 + rl;
            float g[kMaxTok], u[kMaxTok];
            mx_iq3s_row(blob + (size_t) r * gu_row, s_tok, nt, slot, iq3s_fma, lane, g);
            mx_iq3s_row(blob + up_off + (size_t) r * gu_row, s_tok, nt, slot, iq3s_fma, lane, u);
            if (lane == 0) {
#pragma unroll
                for (int t = 0; t < kMaxTok; ++t) {
                    if (t < nt) {   // native_gu_rows: (g / (1.f + std::exp(-g))) * u
                        const float e = mx_expf(-g[t], exp_fma);
                        s_h[t][rl] = __fmul_rn(__fdiv_rn(g[t], __fadd_rn(1.f, e)), u[t]);
                    }
                }
            }
        }
        __syncthreads();
        if (w < nt) {   // warp w: entry e0 + w's Q8_0 block `chunk` (arm quantize_row_q8_0)
            const float hv = s_h[w][lane];
            float am = fabsf(hv);
            for (int o = 16; o > 0; o >>= 1) am = fmaxf(am, __shfl_xor_sync(0xffffffffu, am, o));
            const float d = __fdiv_rn(am, 127.f);
            const float id = d != 0.f ? __fdiv_rn(1.f, d) : 0.f;
            g_hq[slot][e0 + w][chunk * 32 + lane] = (int8_t) __float2int_rn(__fmul_rn(hv, id));
            if (lane == 0) g_hd[slot][e0 + w][chunk] = __half_as_ushort(__float2half_rn(d));
        }
    }
}

// 5. 32 down rows (n_ff 640 = 20 IQ4_NL blocks: lane l < 20 takes block l) of one group per thread block
__global__ void __launch_bounds__(256) mx_down_kernel(size_t d_row, size_t down_off, const unsigned long long* __restrict__ grp_ptr,
                                                      const int32_t* __restrict__ grp_start, const int32_t* __restrict__ n_groups,
                                                      const int32_t* __restrict__ ent_dst, int slot, int form,
                                                      float* __restrict__ out) {
    const int ng = *n_groups;
    const int lane = threadIdx.x & 31, w = threadIdx.x >> 5;
    const bool own = lane < kNbH;
    for (int q = blockIdx.y; q < ng; q += gridDim.y) {
        const int e0 = grp_start[q], nt = min(grp_start[q + 1] - e0, kMaxTok);
        const uint8_t* base = (const uint8_t*) grp_ptr[q] + down_off;
        for (int rr = 0; rr < 4; ++rr) {
            const int r = (blockIdx.x * 8 + w) * 4 + rr;
            const uint8_t* b = base + (size_t) r * d_row + (size_t) (own ? lane : 0) * kIq4nlBytes;
            int lo[4] = {0, 0, 0, 0}, hi[4] = {0, 0, 0, 0};
            float xd = 0.f;
            if (own) {
                xd = __half2float(*reinterpret_cast<const __half*>(b));
#pragma unroll
                for (int k = 0; k < 4; ++k) {   // weights 4k..4k+3 (low nibbles) and 16+4k.. (high nibbles)
                    uint32_t l4 = 0, h4 = 0;
#pragma unroll
                    for (int bb = 0; bb < 4; ++bb) {
                        const uint32_t v = b[2 + 4 * k + bb];
                        l4 |= (uint32_t) (uint8_t) kvalues_iq4nl[v & 15u] << (8 * bb);
                        h4 |= (uint32_t) (uint8_t) kvalues_iq4nl[v >> 4] << (8 * bb);
                    }
                    lo[k] = (int) l4;
                    hi[k] = (int) h4;
                }
            }
#pragma unroll
            for (int t = 0; t < kMaxTok; ++t) {
                if (t < nt) {   // the same on every lane
                    int s = 0;
                    float yd = 0.f;
                    if (own) {
                        const int* hq = reinterpret_cast<const int*>(&g_hq[slot][e0 + t][32 * lane]);
#pragma unroll
                        for (int k = 0; k < 4; ++k) s = __dp4a(lo[k], hq[k], s);
#pragma unroll
                        for (int k = 0; k < 4; ++k) s = __dp4a(hi[k], hq[4 + k], s);
                        yd = __half2float(__ushort_as_half(g_hd[slot][e0 + t][lane]));
                    }
                    const float xy = __fmul_rn(xd, yd);   // X on even lanes, Y on odd ones
                    const float c = __int2float_rn(s);   // C / F
                    const float xy1 = __shfl_down_sync(0xffffffffu, xy, 1), c1 = __shfl_down_sync(0xffffffffu, c, 1);
                    const float tp = form == 0 ? __fmaf_rn(xy, c, __fmul_rn(xy1, c1))
                                   : form == 1 ? __fadd_rn(__fmul_rn(xy, c), __fmul_rn(xy1, c1))
                                               : __fmaf_rn(xy1, c1, __fmul_rn(xy, c));
                    float sumf = 0.f;
#pragma unroll
                    for (int p = 0; p < kNbH / 2; ++p) sumf = __fadd_rn(sumf, __shfl_sync(0xffffffffu, tp, 2 * p));
                    if (lane == 0) out[(size_t) ent_dst[e0 + t] * kEmbd + r] = sumf;
                }
            }
        }
    }
}

// check mode: every float of the replica's rows against the CPU's (mapped) rows of the same entries, bit for bit
__global__ void __launch_bounds__(256) mx_compare_kernel(const int32_t* __restrict__ grp_start,
                                                         const int32_t* __restrict__ n_groups,
                                                         const int32_t* __restrict__ ent_dst, const float* cpu,
                                                         const float* __restrict__ side, int layer,
                                                         MxCheck* __restrict__ ck) {
    const int ng = *n_groups;
    if (ng <= 0) return;   // the same on every block: none reaches the done count
    const int e_end = grp_start[ng];
    unsigned long long all = 0, bad = 0;
    for (int e = grp_start[0] + blockIdx.y; e < e_end; e += gridDim.y) {
        const int d = ent_dst[e];
        for (int r = blockIdx.x * blockDim.x + threadIdx.x; r < kEmbd; r += gridDim.x * blockDim.x) {
            const unsigned gb = __float_as_uint(side[(size_t) d * kEmbd + r]);
            const unsigned cb = __float_as_uint(((const volatile float*) cpu)[(size_t) d * kEmbd + r]);
            ++all;
            if (gb != cb) {
                ++bad;
                if (atomicCAS(&g_ck_first, 0u, 1u) == 0u) {   // the first unequal float, once per process
                    ck->layer = layer; ck->entry = d; ck->row = r; ck->gpu = gb; ck->cpu = cb;
                    __threadfence_system();
                    ck->have = 1;
                }
            }
        }
    }
    if (all != 0) atomicAdd(&g_ck_all, all);
    if (bad != 0) atomicAdd(&g_ck_bad, bad);
    __syncthreads();
    if (threadIdx.x == 0) {
        __threadfence();
        if (atomicAdd(&g_ck_done, 1u) == gridDim.x * gridDim.y - 1) {   // the last block publishes the totals
            ck->all = atomicAdd(&g_ck_all, 0ull);
            ck->bad = atomicAdd(&g_ck_bad, 0ull);
            g_ck_done = 0;
            __threadfence_system();
        }
    }
}

}  // namespace

int miss_exact_mode() {
    static const int mode = [] {
        const char* v = std::getenv("STRATA_MISS_GPU_EXACT");
        return v == nullptr ? 0 : v[0] == '1' ? 1 : v[0] == '2' ? 2 : 0;
    }();
    return mode;
}

bool miss_exact_enabled() { return miss_exact_mode() != 0; }

float* miss_exact_side(int slot) { return h_side != nullptr ? h_side + (size_t) slot * kMaxEntries * kEmbd : nullptr; }

void miss_exact_compare(const int32_t* grp_start, const int32_t* n_groups, const int32_t* ent_dst, const float* cpu_rows,
                        int slot, int layer, void* stream) {
    if (d_ck == nullptr) return;
    mx_compare_kernel<<<dim3(kEmbd / 256, 8), 256, 0, (cudaStream_t) stream>>>(grp_start, n_groups, ent_dst, cpu_rows,
                                                                               miss_exact_side(slot), layer, d_ck);
    const cudaError_t e = cudaGetLastError();
    if (e != cudaSuccess) {
        std::fprintf(stderr, "miss_exact_compare: %s\n", cudaGetErrorString(e));
        std::exit(1);
    }
}

void miss_exact_report() {
    if (h_ck == nullptr) return;
    const volatile MxCheck* c = h_ck;
    static unsigned long long last = 0;
    static bool told = false;
    if (!told && c->have) {
        told = true;
        std::fprintf(stderr, "strata miss_exact check: first unequal float: layer %d entry %d row %d gpu %08x cpu %08x\n",
                     c->layer, c->entry, c->row, c->gpu, c->cpu);
    }
    const unsigned long long all = c->all;
    if ((all >> 20) != (last >> 20)) {   // about every million floats (~400 expert rows of 2560)
        last = all;
        std::fprintf(stderr, "strata miss_exact check: %llu floats compared, %llu unequal\n", all, (unsigned long long) c->bad);
    }
}

bool miss_exact_init(std::string& err) {
    static bool done = false;
    if (done) return true;
    unsigned long long tab[32];
    for (int i = 0; i < 32; ++i) {   // as rep_expf: 2^(i/32) from quad-precision exp2l (aarch64), rounded to double
        const double v = (double) std::exp2((long double) i / 32);
        unsigned long long b;
        std::memcpy(&b, &v, 8);
        tab[i] = b - ((unsigned long long) i << 47);
    }
    cudaError_t e = cudaMemcpyToSymbol(c_exp_tab, tab, sizeof(tab));
    if (e == cudaSuccess && miss_exact_mode() == 2)
        e = cudaMalloc((void**) &h_side, sizeof(float) * (size_t) kSlots * kMaxEntries * kEmbd);
    if (e == cudaSuccess && miss_exact_mode() == 2) e = cudaHostAlloc((void**) &h_ck, sizeof(MxCheck), cudaHostAllocMapped);
    if (e == cudaSuccess && miss_exact_mode() == 2) {
        std::memset((void*) h_ck, 0, sizeof(MxCheck));
        e = cudaHostGetDevicePointer((void**) &d_ck, h_ck, 0);
    }
    if (e != cudaSuccess) {
        err = std::string("STRATA_MISS_GPU_EXACT: init: ") + cudaGetErrorString(e);
        return false;
    }
    const Forms f = forms();
    std::fprintf(stderr, "strata verify: STRATA_MISS_GPU_EXACT=%d: the PCIe share of the misses runs ggml-cpu's rounding on "
                         "the GPU%s (forms q8k %s, iq3s %s, expf %s, iq4nl %d; exp table [1] %016llx [31] %016llx)\n",
                 miss_exact_mode(), miss_exact_mode() == 2 ? " beside the CPU, rows compared (check mode)" : "",
                 f.q8k ? "fused" : "split", f.iq3s ? "fma" : "mul+add", f.expf ? "fma" : "split", f.iq4nl, tab[1], tab[31]);
    done = true;
    return true;
}

bool miss_exact_supported(const NativeExpertLayout& L, int n_tok, int64_t n_entries, int slot) {
    return L.gu_type == 21 && L.d_type == 20 && L.n_embd == kEmbd && L.n_ff == kFF &&   // ggml IQ3_S / IQ4_NL
           n_tok >= 1 && n_tok <= kMaxTok && n_entries <= kMaxEntries && slot >= 0 && slot < kSlots;
}

void miss_exact_grouped(const NativeExpertLayout& L, const unsigned long long* grp_ptr, const int32_t* grp_start,
                        const int32_t* n_groups, const int32_t* ent_dst, const int32_t* ent_tok, const float* x,
                        int n_tok, int slot, float* out, void* stream, int grid_groups) {
    const Forms f = forms();
    cudaStream_t s = (cudaStream_t) stream;
    const int gy = grid_groups > 0 ? grid_groups : 1;
    mx_q8k_kernel<<<dim3(kNbX, n_tok), 256, 0, s>>>(x, n_groups, slot, f.q8k);
    mx_gu_kernel<<<dim3(kFF / 32, gy), 256, 0, s>>>(L.gu_row, L.up_off, grp_ptr, grp_start, n_groups, ent_tok, slot,
                                                   f.iq3s, f.expf);
    mx_down_kernel<<<dim3(kEmbd / 32, gy), 256, 0, s>>>(L.d_row, L.down_off, grp_ptr, grp_start, n_groups, ent_dst, slot,
                                                       f.iq4nl, out);
    const cudaError_t e = cudaGetLastError();
    if (e != cudaSuccess) {
        std::fprintf(stderr, "miss_exact_grouped: %s\n", cudaGetErrorString(e));
        std::exit(1);
    }
}

}  // namespace strata::kernels
