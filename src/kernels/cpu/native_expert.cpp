// src/kernels/cpu/native_expert.cpp - plan v0.3 P6: native (GGUF-form) experts on the CPU through ggml-cpu.
// See the header. The default activation quantizers and row dot products are ggml-cpu's. Explicitly opt-in Q8_1
// diagnostic routes for IQ2_S/Q2_0, IQ2_S/IQ4_NL, IQ3_XXS/Q2_0, IQ3_XXS/IQ4_NL and IQ3_S/IQ4_NL are implemented
// below for cross-backend tests.
#include "strata/kernels/cpu/native_expert.hpp"
#include "strata/kernels/cpu/expert.hpp"
#include "strata/platform/cpu_arch.hpp"
#include "strata/kernels/cpu/iq_avx512.hpp"
#include "strata/kernels/cpu/iq_avx2.hpp"
#include "strata/kernels/cpu/kq_avx2.hpp"
#include "strata/kernels/cpu/expert_layout.hpp"

#include "ggml.h"
#include "ggml-cpu.h"

#define GGML_COMMON_DECL_CPP
#define GGML_COMMON_IMPL_CPP
#include "ggml-common.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cerrno>
#include <climits>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <mutex>
#include <vector>

#if defined(__aarch64__) && defined(__linux__) && defined(__GNUC__)
#include <arm_neon.h>
#include <sys/auxv.h>
#define STRATA_IQ3S_NEON_MT_BUILD 1
#endif

namespace strata::kernels::cpu {
namespace {

const ggml_type_traits_cpu* traits(int type) { return ggml_get_type_traits_cpu((ggml_type) type); }

bool q8_1_selector_known_one(const char* selector) {
    if (std::strcmp(selector, "0") == 0 || std::strcmp(selector, "1") == 0 ||
        std::strcmp(selector, "all") == 0 || std::strcmp(selector, "iq2_s/q2_0") == 0 ||
        std::strcmp(selector, "iq2_s/iq4_nl") == 0 || std::strcmp(selector, "iq3_xxs/q2_0") == 0 ||
        std::strcmp(selector, "iq3_xxs/iq4_nl") == 0 || std::strcmp(selector, "iq3_s/q2_0") == 0 ||
        std::strcmp(selector, "iq3_s/iq4_nl") == 0)
        return true;
    const char* at = std::strstr(selector, "@layer=");
    if (at == nullptr || at == selector) return false;
    const char* n = at + 7;
    if (*n == '\0') return false;
    for (const char* p = n; *p != '\0'; ++p) if (*p < '0' || *p > '9') return false;
    errno = 0;
    char* end = nullptr;
    const long layer = std::strtol(n, &end, 10);
    if (errno == ERANGE || end == n || *end != '\0' || layer > INT_MAX) return false;
    const std::string pair(selector, (size_t) (at - selector));
    return pair == "iq2_s/q2_0" || pair == "iq2_s/iq4_nl" || pair == "iq3_xxs/q2_0" ||
           pair == "iq3_xxs/iq4_nl" || pair == "iq3_s/q2_0" || pair == "iq3_s/iq4_nl";
}

bool q8_1_selector_known(const char* selector) {
    if (std::strchr(selector, ',') == nullptr) return q8_1_selector_known_one(selector);
    const std::string list(selector);
    size_t begin = 0;
    while (begin <= list.size()) {
        const size_t end = list.find(',', begin);
        const std::string item = list.substr(begin, end == std::string::npos ? end : end - begin);
        if (item.empty() || !q8_1_selector_known_one(item.c_str())) return false;
        if (end == std::string::npos) break;
        begin = end + 1;
    }
    return true;
}

bool parse_layer_selector(const char* value, int& layer) {
    if (value == nullptr) return false;
    if (*value == '\0') return false;
    for (const char* p = value; *p != '\0'; ++p) if (*p < '0' || *p > '9') return false;
    errno = 0;
    char* end = nullptr;
    const long parsed = std::strtol(value, &end, 10);
    if (errno == ERANGE || end == value || *end != '\0' || parsed > INT_MAX) return false;
    layer = (int) parsed;
    return true;
}

bool q8_1_selector_matches_one(const char* selector, int gu_type, int d_type, int layer) {
    const char* at = std::strstr(selector, "@layer=");
    if (at != nullptr) {
        char* end = nullptr;
        const long selected_layer = std::strtol(at + 7, &end, 10);
        if (end == at + 7 || *end != '\0' || selected_layer != layer) return false;
    }
    const bool iq2_s_q2_0 = gu_type == GGML_TYPE_IQ2_S && d_type == GGML_TYPE_Q2_0;
    const bool iq2_s_iq4_nl = gu_type == GGML_TYPE_IQ2_S && d_type == GGML_TYPE_IQ4_NL;
    const bool iq3_xxs_q2_0 = gu_type == GGML_TYPE_IQ3_XXS && d_type == GGML_TYPE_Q2_0;
    const bool iq3_xxs_iq4_nl = gu_type == GGML_TYPE_IQ3_XXS && d_type == GGML_TYPE_IQ4_NL;
    const bool iq3_s_q2_0 = gu_type == GGML_TYPE_IQ3_S && d_type == GGML_TYPE_Q2_0;
    const bool iq3_s_iq4_nl = gu_type == GGML_TYPE_IQ3_S && d_type == GGML_TYPE_IQ4_NL;
    const std::string pair = at == nullptr ? selector : std::string(selector, (size_t) (at - selector));
    if (pair == "1" || pair == "all")
        return iq2_s_q2_0 || iq2_s_iq4_nl || iq3_xxs_q2_0 || iq3_xxs_iq4_nl || iq3_s_q2_0 || iq3_s_iq4_nl;
    if (pair == "iq2_s/q2_0") return iq2_s_q2_0;
    if (pair == "iq2_s/iq4_nl") return iq2_s_iq4_nl;
    if (pair == "iq3_xxs/q2_0") return iq3_xxs_q2_0;
    if (pair == "iq3_xxs/iq4_nl") return iq3_xxs_iq4_nl;
    if (pair == "iq3_s/q2_0") return iq3_s_q2_0;
    if (pair == "iq3_s/iq4_nl") return iq3_s_iq4_nl;
    return false;
}

bool q8_1_selector_matches(const char* selector, int gu_type, int d_type, int layer) {
    if (std::strchr(selector, ',') == nullptr)
        return q8_1_selector_matches_one(selector, gu_type, d_type, layer);
    const std::string list(selector);
    size_t begin = 0;
    while (begin <= list.size()) {
        const size_t end = list.find(',', begin);
        const std::string item = list.substr(begin, end == std::string::npos ? end : end - begin);
        if (q8_1_selector_matches_one(item.c_str(), gu_type, d_type, layer)) return true;
        if (end == std::string::npos) break;
        begin = end + 1;
    }
    return false;
}

struct Q81Block { ggml_fp16_t d, s; int8_t qs[32]; };
static_assert(sizeof(Q81Block) == 36, "GGML Q8_1 block layout");

float q8_1_iq2_s_cuda_dot(const uint8_t* row, const uint8_t* xq, int n) {
    constexpr int qk = QK_K;
    static_assert(qk == 256, "IQ2_S CUDA contract assumes 256-value weight blocks");
    if (n % qk != 0) std::abort();
    const int nb = n / qk;
    std::array<float, 32> lane_sum{};
    for (int lane = 0; lane < 32; ++lane) {
        for (int k = lane; k < nb * 8; k += 32) {
            const int kbx = k / 8;
            const int iqs = 2 * (k % 8);
            const auto* bq2 = reinterpret_cast<const block_iq2_s*>(row) + kbx;
            const auto* act = reinterpret_cast<const Q81Block*>(xq) + kbx * 8 + iqs / 2;
            const uint8_t* qs = bq2->qs + 4 * (iqs / 2);
            const uint8_t qh = bq2->qh[iqs / 2];
            const uint8_t* packed_signs = bq2->qs + 32 + 4 * (iqs / 2);
            const int ls0 = bq2->scales[iqs / 2] & 0x0f;
            const int ls1 = bq2->scales[iqs / 2] >> 4;
            int sumi0 = 0, sumi1 = 0;
            for (int l0 = 0; l0 < 8; l0 += 2) {
                const int grid_index = qs[l0 / 2] | ((qh << (8 - l0)) & 0x300);
                const uint64_t grid = iq2s_grid[grid_index];
                const uint8_t signs = packed_signs[l0 / 2];
                const int q8_offset = l0 * 4;
                for (int j = 0; j < 4; ++j) {
                    int gl = (int) ((grid >> (8 * j)) & 0xff);
                    int gh = (int) ((grid >> (8 * (j + 4))) & 0xff);
                    if ((signs >> j) & 1) gl = -gl;
                    if ((signs >> (j + 4)) & 1) gh = -gh;
                    const int part = l0 < 4 ? 0 : 1;
                    if (part == 0) {
                        sumi0 += gl * act->qs[q8_offset + j] + gh * act->qs[q8_offset + 4 + j];
                    } else {
                        sumi1 += gl * act->qs[q8_offset + j] + gh * act->qs[q8_offset + 4 + j];
                    }
                }
            }
            const int sumi = (sumi0 * ls0 + sumi1 * ls1 + (sumi0 + sumi1) / 2) / 4;
            const float d = ggml_fp16_to_fp32(bq2->d) * ggml_fp16_to_fp32(act->d);
            lane_sum[(size_t) lane] += d * (float) sumi;
        }
    }
    for (int offset = 16; offset > 0; offset >>= 1) {
        const auto previous = lane_sum;
        for (int lane = 0; lane < 32; ++lane) lane_sum[(size_t) lane] = previous[(size_t) lane] + previous[(size_t) (lane ^ offset)];
    }
    return lane_sum[0];
}

// The opt-in CUDA-order expert mirror consumes the grouped CUDA Q8_1 producer's
// bytes. GGML's Orin NEON producer uses reciprocal-multiply plus ties-to-even;
// grouped CUDA uses roundf(x / d). Keep the activation contract aligned at this
// seam while leaving all non-Q8_1/default routes on ggml-cpu.
void quantize_q8_1_cuda_order(const float* x, int n, void* dst) {
    if (n % 32 != 0) std::abort();
    auto* blocks = static_cast<Q81Block*>(dst);
    for (int block = 0; block < n / 32; ++block) {
        const float* row = x + (size_t) block * 32;
        float amax = 0.f;
        std::array<float, 32> sums{};
        for (int lane = 0; lane < 32; ++lane) {
            amax = std::max(amax, std::fabs(row[lane]));
            sums[(size_t) lane] = row[lane];
        }
        for (int offset = 16; offset > 0; offset >>= 1) {
            const auto prior = sums;
            for (int lane = 0; lane < 32; ++lane)
                sums[(size_t) lane] = prior[(size_t) lane] + prior[(size_t) (lane ^ offset)];
        }
        const float d = amax / 127.f;
        blocks[block].d = ggml_fp32_to_fp16(std::fabs(d) > 65504.f ? std::copysign(65504.f, d) : d);
        const float sum = sums[0];
        blocks[block].s = ggml_fp32_to_fp16(std::fabs(sum) > 65504.f ? std::copysign(65504.f, sum) : sum);
        for (int lane = 0; lane < 32; ++lane) {
            const int q = amax == 0.f ? 0 : std::clamp((int) std::round(row[lane] / d), -127, 127);
            blocks[block].qs[lane] = (int8_t) q;
        }
    }
}

float q8_1_iq3_xxs_cuda_dot(const uint8_t* row, const uint8_t* xq, int n) {
    // Mirrors vec_dot_iq3_xxs_q8_1 / Fmt<18> in cuda/iq_kernels.cu for the opt-in CPU-owner diagnostic.
    constexpr int qk = QK_K;
    static_assert(qk == 256, "IQ3_XXS CUDA contract assumes 256-value weight blocks");
    if (n % qk != 0) std::abort();
    const int nb = n / qk;
    const auto* weights = reinterpret_cast<const block_iq3_xxs*>(row);
    const auto* acts = reinterpret_cast<const Q81Block*>(xq);
    std::array<float, 32> lane_sum{};
    for (int lane = 0; lane < 32; ++lane) {
        for (int k = lane; k < nb * 8; k += 32) {
            const int kbx = k / 8;
            const int iqs = 2 * (k % 8);
            const auto* w = weights + kbx;
            const auto* x = acts + kbx * 8 + iqs / 2;
            uint32_t packed[2];
            std::memcpy(&packed[0], w->qs + 4 * iqs, sizeof(uint32_t));
            std::memcpy(&packed[1], w->qs + 4 * (iqs + 1), sizeof(uint32_t));
            uint8_t q3[8];
            std::memcpy(q3, packed, sizeof(q3));
            uint32_t aux32;
            std::memcpy(&aux32, w->qs + 4 * (QK_K / 16 + iqs / 2), sizeof(aux32));
            int sumi = 0;
            for (int l0 = 0; l0 < 8; l0 += 2) {
                const uint8_t raw_signs = (uint8_t) (aux32 >> (7 * l0 / 2));
                // CUDA unpack_ksigns replaces bit 7 with parity; only its lower seven bits are sign data.
                const uint8_t sign_bits = raw_signs ^ ((uint8_t) (__builtin_popcount((unsigned) raw_signs) & 1) << 7);
                const uint32_t grid_l = iq3xxs_grid[q3[l0 + 0]];
                const uint32_t grid_h = iq3xxs_grid[q3[l0 + 1]];
                for (int j = 0; j < 4; ++j) {
                    int gl = (int8_t) (grid_l >> (8 * j));
                    int gh = (int8_t) (grid_h >> (8 * j));
                    if ((sign_bits >> j) & 1) gl = -gl;
                    if ((sign_bits >> (j + 4)) & 1) gh = -gh;
                    sumi += gl * (int) x->qs[4 * l0 + j];
                    sumi += gh * (int) x->qs[4 * (l0 + 1) + j];
                }
            }
            const int ls = (int) (aux32 >> 28);
            sumi = (ls * sumi + sumi / 2) / 2;
            const float d = ggml_fp16_to_fp32(w->d) * ggml_fp16_to_fp32(x->d);
            lane_sum[(size_t) lane] += d * (float) sumi;
        }
    }
    for (int offset = 16; offset > 0; offset >>= 1) {
        const auto previous = lane_sum;
        for (int lane = 0; lane < 32; ++lane)
            lane_sum[(size_t) lane] = previous[(size_t) lane] + previous[(size_t) (lane ^ offset)];
    }
    return lane_sum[0];
}

float q8_1_iq3_s_cuda_dot(const uint8_t* row, const uint8_t* xq, int n) {
    // Mirror vec_dot_iq3_s_q8_1 / Fmt<21> in cuda/iq_kernels.cu and the
    // grouped expert's 32-lane strided accumulation plus XOR reduction.
    constexpr int qk = QK_K;
    static_assert(qk == 256, "IQ3_S CUDA contract assumes 256-value weight blocks");
    if (n % qk != 0) std::abort();
    const int nb = n / qk;
    const auto* weights = reinterpret_cast<const block_iq3_s*>(row);
    const auto* acts = reinterpret_cast<const Q81Block*>(xq);
    std::array<float, 32> lane_sum{};
    for (int lane = 0; lane < 32; ++lane) {
        for (int k = lane; k < nb * 8; k += 32) {
            const int kbx = k / 8;
            const int iqs = 2 * (k % 8);
            const auto* w = weights + kbx;
            const auto* x = acts + kbx * 8 + iqs / 2;
            const uint8_t* qs = w->qs + 4 * iqs;
            const uint8_t qh = w->qh[iqs / 2];
            const uint8_t* signs = w->signs + 4 * (iqs / 2);
            int sumi = 0;
            for (int l0 = 0; l0 < 8; l0 += 2) {
                const uint32_t grid_l = iq3s_grid[qs[l0] | ((qh << (8 - l0)) & 0x100)];
                const uint32_t grid_h = iq3s_grid[qs[l0 + 1] | ((qh << (7 - l0)) & 0x100)];
                const uint8_t sign = signs[l0 / 2];
                for (int j = 0; j < 4; ++j) {
                    int gl = (int) ((grid_l >> (8 * j)) & 0xff);
                    int gh = (int) ((grid_h >> (8 * j)) & 0xff);
                    if ((sign >> j) & 1) gl = -gl;
                    if ((sign >> (j + 4)) & 1) gh = -gh;
                    sumi += gl * (int) x->qs[4 * l0 + j];
                    sumi += gh * (int) x->qs[4 * (l0 + 1) + j];
                }
            }
            const int scale = 1 + 2 * ((w->scales[iqs / 4] >> ((iqs << 1) & 0x04)) & 0x0f);
            sumi *= scale;
            const float d = ggml_fp16_to_fp32(w->d) * ggml_fp16_to_fp32(x->d);
            lane_sum[(size_t) lane] += d * (float) sumi;
        }
    }
    for (int offset = 16; offset > 0; offset >>= 1) {
        const auto previous = lane_sum;
        for (int lane = 0; lane < 32; ++lane)
            lane_sum[(size_t) lane] = previous[(size_t) lane] + previous[(size_t) (lane ^ offset)];
    }
    return lane_sum[0];
}

float q8_1_q2_0_cuda_dot(const uint8_t* row, const uint8_t* xq, int n) {
    constexpr int qk = QK2_0;
    if (n % qk != 0) std::abort();
    const int nb = n / qk;
    constexpr int8_t lut[4] = {-1, 0, 1, 2};
    std::array<float, 32> lane_sum{};
    for (int lane = 0; lane < 32; ++lane) {
        for (int k = lane; k < nb * 2; k += 32) {
            const int kbx = k / 2;
            const int iqs = k % 2;
            const auto* bq2 = reinterpret_cast<const block_q2_0*>(row) + kbx;
            const auto* act = reinterpret_cast<const Q81Block*>(xq) + kbx * 2 + iqs;
            int sumi = 0;
            for (int j = 0; j < 4; ++j) {
                const uint16_t q = (uint16_t) bq2->qs[iqs * 8 + j * 2] |
                                   ((uint16_t) bq2->qs[iqs * 8 + j * 2 + 1] << 8);
                // CUDA byte_perm(0x5140/0x7362) interleaves even and odd 2-bit
                // fields into the two four-byte activation chunks.
                for (int i = 0; i < 4; ++i) {
                    const int code0 = lut[(q >> (2 * i)) & 3];
                    const int code1 = lut[(q >> (2 * (i + 4))) & 3];
                    sumi += code0 * act->qs[j * 8 + i] + code1 * act->qs[j * 8 + 4 + i];
                }
            }
            const float d = ggml_fp16_to_fp32(bq2->d) * ggml_fp16_to_fp32(act->d);
            lane_sum[(size_t) lane] += d * (float) sumi;
        }
    }
    for (int offset = 16; offset > 0; offset >>= 1) {
        const auto previous = lane_sum;
        for (int lane = 0; lane < 32; ++lane) lane_sum[(size_t) lane] = previous[(size_t) lane] + previous[(size_t) (lane ^ offset)];
    }
    return lane_sum[0];
}

float q8_1_iq4_nl_cuda_dot(const uint8_t* row, const uint8_t* xq, int n) {
    constexpr int qk = QK4_NL;
    static_assert(qk == 32, "IQ4_NL CUDA contract assumes 32-value weight blocks");
    if (n % qk != 0) std::abort();
    const int blocks = n / qk;
    const auto* weights = reinterpret_cast<const block_iq4_nl*>(row);
    const auto* acts = reinterpret_cast<const Q81Block*>(xq);

    // Match native_down_multi_kernel's IQ4_NL row_dot_multi path, which is the
    // grouped expert kernel used by the service. Each output row uses one warp;
    // each lane walks k = lane, lane + 32, ... across the 2 sub-blocks per
    // Q8_1 block, then the warp reduces with the CUDA XOR tree. This differs
    // from standalone native_small_mmvq's four-warp mapping.
    std::array<float, 32> lane_sum{};
    for (int lane = 0; lane < 32; ++lane) {
        float acc = 0.0f;
        for (int k = lane; k < blocks * 2; k += 32) {
            const int block = k / 2;
            const int iqs = 2 * (k % 2);
            const auto* w = weights + block;
            const auto* x = acts + block;
            int sumi = 0;
            for (int i = 0; i < 2; ++i) {
                const int group = iqs + i;
                const uint8_t* packed = w->qs + 4 * group;
                for (int j = 0; j < 4; ++j) {
                    sumi += (int) kvalues_iq4nl[packed[j] & 0x0f] * (int) x->qs[4 * group + j];
                    sumi += (int) kvalues_iq4nl[packed[j] >> 4] * (int) x->qs[16 + 4 * group + j];
                }
            }
            const float d = ggml_fp16_to_fp32(w->d) * ggml_fp16_to_fp32(x->d);
            acc += d * (float) sumi;
        }
        lane_sum[(size_t) lane] = acc;
    }
    for (int offset = 16; offset > 0; offset >>= 1) {
        const auto previous = lane_sum;
        for (int lane = 0; lane < 32; ++lane) {
            lane_sum[(size_t) lane] = previous[(size_t) lane] + previous[(size_t) (lane ^ offset)];
        }
    }
    return lane_sum[0];
}

bool q8_1_scalar_dot(const NativeFmt& f) {
    const bool iq2_s_pair = f.gu_type == GGML_TYPE_IQ2_S &&
                            (f.d_type == GGML_TYPE_Q2_0 || f.d_type == GGML_TYPE_IQ4_NL);
    const bool iq3_xxs_pair = f.gu_type == GGML_TYPE_IQ3_XXS &&
                              (f.d_type == GGML_TYPE_Q2_0 || f.d_type == GGML_TYPE_IQ4_NL);
    const bool iq3_s_pair = f.gu_type == GGML_TYPE_IQ3_S &&
                            (f.d_type == GGML_TYPE_Q2_0 || f.d_type == GGML_TYPE_IQ4_NL);
    return (iq2_s_pair || iq3_xxs_pair || iq3_s_pair) &&
           f.gu_act == GGML_TYPE_Q8_1 && f.d_act == GGML_TYPE_Q8_1;
}

void init_once() {
    static std::once_flag once;
    std::call_once(once, [] { ggml_cpu_init(); });
}

#ifdef STRATA_IQ3S_NEON_MT_BUILD
// STRATA_IQ3S_NEON_MT=1|2 (opt-in, aarch64 Linux): an expert's IQ3_S gate/up rows for its 2..MAXT window tokens with
// each 256-weight block decoded once for all of them (ggml's dot decodes it again for every token).  Per token every
// step is ggml's NEON ggml_vec_dot_iq3_s_q8_K: the same signed grid bytes, exact integer sums (lane order cannot
// matter in integers), and per block `sumf += d*(sumi1 + sumi2)` with d = fp16(x.d) * y.d.  That one float step is
// what ggml's build may compile either way: mode 1 = one fused multiply-add (GCC's default contraction in gnu11 C),
// mode 2 = a rounded multiply, then the add.  The served texts-identical gate decides which one is ggml's.
int iq3s_neon_mt_mode() {
    static const int mode = [] {
        const char* v = std::getenv("STRATA_IQ3S_NEON_MT");
        const int m = v != nullptr ? std::atoi(v) : 0;
        if (m != 1 && m != 2) return 0;
        if ((getauxval(AT_HWCAP) & (1UL << 20)) == 0) {   // HWCAP_ASIMDDP: the dot-product instructions
            std::fprintf(stderr, "strata native experts: STRATA_IQ3S_NEON_MT=%d ignored: this CPU has no dot product\n", m);
            return 0;
        }
        std::fprintf(stderr, "strata native experts: STRATA_IQ3S_NEON_MT=%d: IQ3_S gate/up rows decode each block once "
                             "for 2-%d tokens (%s)\n", m, MAXT, m == 1 ? "fused multiply-add accumulate" : "multiply, then add");
        return m;
    }();
    return mode;
}

#pragma GCC push_options
#pragma GCC target("arch=armv8.2-a+dotprod")
// out[t] = ggml_vec_dot_iq3_s_q8_K(n, row, act[t]) for t < nt (ggml-cpu/arch/arm/quants.c, the __ARM_NEON branch)
void iq3s_dot_mt(const uint8_t* row, const void* const* act, int nt, int n, int mode, float* out) {
    static const uint8_t k_mask1[32] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
                                        0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03};
    static const uint8_t k_mask2[16] = {0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80};
    static const int16_t k_shift[8] = {8, 7, 6, 5, 4, 3, 2, 1};
    const uint8x16_t mask1_0 = vld1q_u8(k_mask1), mask1_1 = vld1q_u8(k_mask1 + 16);
    const uint8x16_t mask2 = vld1q_u8(k_mask2);
    const int16x8_t hshift = vld1q_s16(k_shift);
    const uint16x8_t m256 = vdupq_n_u16(256);
    const uint8x16_t m1 = vdupq_n_u8(1);
    const auto* x = reinterpret_cast<const block_iq3_s*>(row);
    const int nb = n / QK_K;
    float sumf[MAXT];
    for (int t = 0; t < nt; ++t) sumf[t] = 0.f;
    for (int i = 0; i < nb; ++i) {
        const uint8_t* qs = x[i].qs;
        const uint8_t* qh = x[i].qh;
        const uint8_t* sg = x[i].signs;
        uint32_t scales32[2];
        std::memcpy(scales32, x[i].scales, 4);
        scales32[1] = (((scales32[0] >> 4) & 0x0f0f0f0f) << 1) | 0x01010101;
        scales32[0] = ((scales32[0] & 0x0f0f0f0f) << 1) | 0x01010101;
        const auto* scales8 = reinterpret_cast<const uint8_t*>(scales32);
        int sumi1[MAXT], sumi2[MAXT];
        for (int t = 0; t < nt; ++t) sumi1[t] = sumi2[t] = 0;
        for (int ib32 = 0; ib32 < QK_K / 32; ib32 += 2) {
            uint16_t idx[8];
            const uint8x16_t idx_l = vld1q_u8(qs);
            qs += 16;
            vst1q_u16(idx, vorrq_u16(vmovl_u8(vget_low_u8(idx_l)),
                                     vandq_u16(vshlq_u16(vdupq_n_u16(qh[ib32 + 0]), hshift), m256)));
            const uint32_t a0[4] = {iq3s_grid[idx[0]], iq3s_grid[idx[1]], iq3s_grid[idx[2]], iq3s_grid[idx[3]]};
            const uint32_t a1[4] = {iq3s_grid[idx[4]], iq3s_grid[idx[5]], iq3s_grid[idx[6]], iq3s_grid[idx[7]]};
            vst1q_u16(idx, vorrq_u16(vmovl_u8(vget_high_u8(idx_l)),
                                     vandq_u16(vshlq_u16(vdupq_n_u16(qh[ib32 + 1]), hshift), m256)));
            const uint32_t a2[4] = {iq3s_grid[idx[0]], iq3s_grid[idx[1]], iq3s_grid[idx[2]], iq3s_grid[idx[3]]};
            const uint32_t a3[4] = {iq3s_grid[idx[4]], iq3s_grid[idx[5]], iq3s_grid[idx[6]], iq3s_grid[idx[7]]};
            uint16_t s16[4];
            std::memcpy(s16, sg, sizeof(s16));
            sg += sizeof(s16);
            int8x16_t q3s[4];
            uint8x16_t vs0 = vreinterpretq_u8_u32(vdupq_n_u32(s16[0] | ((uint32_t) s16[1] << 16)));
            uint8x16_t vs1 = vandq_u8(vqtbl1q_u8(vs0, mask1_1), mask2);
            vs0 = vandq_u8(vqtbl1q_u8(vs0, mask1_0), mask2);
            vs0 = vorrq_u8(vceqq_u8(vs0, mask2), m1);
            vs1 = vorrq_u8(vceqq_u8(vs1, mask2), m1);
            q3s[0] = vmulq_s8(vreinterpretq_s8_u8(vs0), vreinterpretq_s8_u32(vld1q_u32(a0)));
            q3s[1] = vmulq_s8(vreinterpretq_s8_u8(vs1), vreinterpretq_s8_u32(vld1q_u32(a1)));
            vs0 = vreinterpretq_u8_u32(vdupq_n_u32(s16[2] | ((uint32_t) s16[3] << 16)));
            vs1 = vandq_u8(vqtbl1q_u8(vs0, mask1_1), mask2);
            vs0 = vandq_u8(vqtbl1q_u8(vs0, mask1_0), mask2);
            vs0 = vorrq_u8(vceqq_u8(vs0, mask2), m1);
            vs1 = vorrq_u8(vceqq_u8(vs1, mask2), m1);
            q3s[2] = vmulq_s8(vreinterpretq_s8_u8(vs0), vreinterpretq_s8_u32(vld1q_u32(a2)));
            q3s[3] = vmulq_s8(vreinterpretq_s8_u8(vs1), vreinterpretq_s8_u32(vld1q_u32(a3)));
            for (int t = 0; t < nt; ++t) {
                const int8_t* q8 = reinterpret_cast<const block_q8_K*>(act[t])[i].qs + 32 * ib32;
                const int32x4_t p1 = vdotq_s32(vdotq_s32(vdupq_n_s32(0), q3s[0], vld1q_s8(q8)), q3s[1], vld1q_s8(q8 + 16));
                const int32x4_t p2 = vdotq_s32(vdotq_s32(vdupq_n_s32(0), q3s[2], vld1q_s8(q8 + 32)), q3s[3], vld1q_s8(q8 + 48));
                sumi1[t] += vaddvq_s32(p1) * scales8[ib32 / 2 + 0];
                sumi2[t] += vaddvq_s32(p2) * scales8[ib32 / 2 + 4];
            }
        }
        const float xd = ggml_fp16_to_fp32(x[i].d);
        for (int t = 0; t < nt; ++t) {
            const float d = xd * reinterpret_cast<const block_q8_K*>(act[t])[i].d;
            const float s = (float) (sumi1[t] + sumi2[t]);
            if (mode == 1) {
                sumf[t] = std::fma(d, s, sumf[t]);
            } else {
                float p = d * s;
                __asm__ volatile("" : "+w"(p));   // keep the multiply rounded: no contraction into the add
                sumf[t] = sumf[t] + p;
            }
        }
    }
    for (int t = 0; t < nt; ++t) out[t] = sumf[t];
}
#pragma GCC pop_options

// STRATA_MISS_REPLICA_CHECK=1 (diagnostic, read-only): every quantity of the CPU-miss path that ggml-cpu (or this file's
// SiLU line) rounds is recomputed here with explicit operations, one replica per guess of how the compiler built the
// float steps, and the bit-equal results are counted.  It answers whether a GPU port of the miss path can round exactly
// like the CPU (texts identical) and which form to port: Q8_K of x (the magic-bias add fused into the scale multiply or
// not), the IQ3_S x Q8_K dot (iq3s_dot_mt at one token, modes 1/2), expf (glibc's e_expf.c algorithm, its polynomial
// with or without fused multiply-adds), Q8_0 of h (one form: ggml's NEON body is multiplies and a nearest-even convert)
// and the IQ4_NL x Q8_0 dot (three forms of its block-pair line).  The engine keeps using ggml's results.
enum { RC_Q8K = 0, RC_IQ3S, RC_EXP, RC_Q80, RC_IQ4NL, RC_N };
constexpr int RC_FORMS = 3;
std::atomic<unsigned long long> rc_ok[RC_N][RC_FORMS];
std::atomic<unsigned long long> rc_all[RC_N];

bool replica_check() {
    static const bool on = [] {
        const char* v = std::getenv("STRATA_MISS_REPLICA_CHECK");
        if (v == nullptr || v[0] != '1') return false;
        if ((getauxval(AT_HWCAP) & (1UL << 20)) == 0) {   // iq3s_dot_mt needs the dot-product instructions
            std::fprintf(stderr, "strata native experts: STRATA_MISS_REPLICA_CHECK=1 ignored: this CPU has no dot product\n");
            return false;
        }
        std::fprintf(stderr, "strata native experts: STRATA_MISS_REPLICA_CHECK=1: counting bit-equal replicas of the CPU "
                             "miss path (lines `strata replica check:`)\n");
        return true;
    }();
    return on;
}

void rc_print() {
    const auto ok = [](int p, int m) { return rc_ok[p][m].load(std::memory_order_relaxed); };
    const auto all = [](int p) { return rc_all[p].load(std::memory_order_relaxed); };
    std::fprintf(stderr, "strata replica check (bit-equal of total): q8_K(x) rows %llu: fused %llu, split %llu | iq3_s dots "
                         "%llu: fma %llu, mul+add %llu | expf %llu: fma poly %llu, split poly %llu | q8_0(h) rows %llu: "
                         "%llu | iq4_nl dots %llu: fma(X,C,Y*F) %llu, X*C+Y*F %llu, fma(Y,F,X*C) %llu\n",
                 all(RC_Q8K), ok(RC_Q8K, 0), ok(RC_Q8K, 1), all(RC_IQ3S), ok(RC_IQ3S, 0), ok(RC_IQ3S, 1), all(RC_EXP),
                 ok(RC_EXP, 0), ok(RC_EXP, 1), all(RC_Q80), ok(RC_Q80, 0), all(RC_IQ4NL), ok(RC_IQ4NL, 0),
                 ok(RC_IQ4NL, 1), ok(RC_IQ4NL, 2));
}

void rc_add(int piece, const unsigned long long* ok, unsigned long long n) {
    for (int m = 0; m < RC_FORMS; ++m)
        if (ok[m] != 0) rc_ok[piece][m].fetch_add(ok[m], std::memory_order_relaxed);
    const unsigned long long before = rc_all[piece].fetch_add(n, std::memory_order_relaxed);
    // a cumulative line at the first gate/up rows and then every 2^23 dots (the server is stopped by a signal)
    if (piece == RC_IQ3S && (before == 0 || (before >> 23) != ((before + n) >> 23))) rc_print();
}

uint32_t fbits(float v) { uint32_t b; std::memcpy(&b, &v, 4); return b; }
void keep_rounded(float& v) { __asm__ volatile("" : "+w"(v)); }    // no contraction across this point
void keep_rounded(double& v) { __asm__ volatile("" : "+w"(v)); }

// ggml-quants.c quantize_row_q8_K_ref; nearest_int(iscale*x) = the magic-bias add, fused into the multiply or not
void rep_q8k(const float* x, block_q8_K* y, int64_t k, bool fused) {
    for (int64_t i = 0; i < k / QK_K; ++i, x += QK_K) {
        float max = 0, amax = 0;
        for (int j = 0; j < QK_K; ++j) {
            const float ax = std::fabs(x[j]);
            if (ax > amax) { amax = ax; max = x[j]; }
        }
        if (!amax) { y[i].d = 0; std::memset(y[i].qs, 0, QK_K); continue; }
        const float iscale = -127.f / max;
        for (int j = 0; j < QK_K; ++j) {
            float val;
            if (fused) {
                val = std::fma(iscale, x[j], 12582912.f);
            } else {
                float p = iscale * x[j];
                keep_rounded(p);
                val = p + 12582912.f;
            }
            const int v = (int) (fbits(val) & 0x007fffff) - 0x00400000;
            y[i].qs[j] = (int8_t) std::min(127, v);
        }
        for (int j = 0; j < QK_K / 16; ++j) {
            int s = 0;
            for (int ii = 0; ii < 16; ++ii) s += y[i].qs[j * 16 + ii];
            y[i].bsums[j] = (int16_t) s;
        }
        y[i].d = 1 / iscale;
    }
}

void rc_q8k(const float* x, const void* dst, int64_t n) {
    block_q8_K rep[16];
    if (n / QK_K > 16) return;
    const auto* g = static_cast<const block_q8_K*>(dst);
    unsigned long long ok[RC_FORMS] = {};
    for (int m = 0; m < 2; ++m) {
        rep_q8k(x, rep, n, m == 0);
        bool same = true;
        for (int64_t i = 0; i < n / QK_K && same; ++i)
            same = fbits(rep[i].d) == fbits(g[i].d) && std::memcmp(rep[i].qs, g[i].qs, QK_K) == 0 &&
                   (g[i].d == 0 || std::memcmp(rep[i].bsums, g[i].bsums, sizeof(rep[i].bsums)) == 0);
        ok[m] = same;
    }
    rc_add(RC_Q8K, ok, 1);
}

// arm/quants.c quantize_row_q8_0 (__ARM_NEON): d = amax/127, id = 1/d, round-to-nearest-even of x*id, d stored fp16
void rc_q80(const float* x, const void* dst, int64_t n) {
    const auto* g = static_cast<const block_q8_0*>(dst);
    bool same = true;
    for (int64_t i = 0; i < n / QK8_0 && same; ++i) {
        const float* xb = x + i * QK8_0;
        float amax = 0;
        for (int j = 0; j < QK8_0; ++j) amax = std::max(amax, std::fabs(xb[j]));
        const float d = amax / 127;
        const float id = d ? 1.0f / d : 0.0f;
        same = ggml_fp32_to_fp16(d) == g[i].d;
        for (int j = 0; j < QK8_0 && same; ++j) same = (int8_t) (int) std::nearbyint(xb[j] * id) == g[i].qs[j];
    }
    const unsigned long long ok[RC_FORMS] = {same ? 1ull : 0ull, 0, 0};
    rc_add(RC_Q80, ok, 1);
}

// glibc sysdeps/ieee754/flt-32/e_expf.c (ARM optimized-routines): 32-entry 2^(i/32) table, cubic in double, aarch64's
// round/lround for k.  The table is rebuilt from quad-precision exp2l (aarch64 long double), rounded to double.
float rep_expf(float x, bool fused) {
    static const std::array<uint64_t, 32> tab = [] {
        std::array<uint64_t, 32> t{};
        for (int i = 0; i < 32; ++i) {
            const double v = (double) std::exp2((long double) i / 32);
            uint64_t b;
            std::memcpy(&b, &v, 8);
            t[(size_t) i] = b - ((uint64_t) i << 47);
        }
        return t;
    }();
    constexpr double N = 32, InvLn2N = 0x1.71547652b82fep+0 * N;
    constexpr double C0 = 0x1.c6af84b912394p-5 / N / N / N, C1 = 0x1.ebfce50fac4f3p-3 / N / N, C2 = 0x1.62e42ff0c52d6p-1 / N;
    if (std::isnan(x)) return x + x;
    if (x > 0x1.62e42ep6f) return INFINITY;
    if (x < -0x1.9fe368p6f) return 0.0f;
    double z = InvLn2N * (double) x;
    keep_rounded(z);
    const double kd = std::round(z);
    const uint64_t ki = (uint64_t) (int64_t) std::lround(z);
    const double r = z - kd;
    uint64_t t = tab[ki % 32];
    t += ki << 47;
    double s;
    std::memcpy(&s, &t, 8);
    double r2 = r * r, p, y;
    keep_rounded(r2);
    if (fused) {
        p = std::fma(C0, r, C1);
        y = std::fma(C2, r, 1.0);
        y = std::fma(p, r2, y);
    } else {
        p = C0 * r;
        keep_rounded(p);
        p = p + C1;
        y = C2 * r;
        keep_rounded(y);
        y = y + 1.0;
        double q = p * r2;
        keep_rounded(q);
        y = q + y;
    }
    y = y * s;
    keep_rounded(y);
    return (float) y;
}

// arm/quants.c ggml_vec_dot_iq4_nl_q8_0 (__ARM_NEON): per block pair `sumf += A*B*C + D*E*F`, X = A*B, Y = D*E;
// form 0 = sumf + fma(X, C, Y*F) (GCC contracting the first product into the sum), 1 = no contraction,
// 2 = sumf + fma(Y, F, X*C).  n_ff is an even number of blocks here; an odd tail returns NaN (never equal).
float rep_iq4nl(const uint8_t* row, const void* act, int n, int form) {
    const auto* x = reinterpret_cast<const block_iq4_nl*>(row);
    const auto* y = reinterpret_cast<const block_q8_0*>(act);
    const int nb = n / QK4_NL;
    if (nb % 2 != 0) return NAN;
    float sumf = 0;
    for (int ib = 0; ib + 1 < nb; ib += 2) {
        int s[2];
        for (int k = 0; k < 2; ++k) {
            int acc = 0;
            for (int j = 0; j < QK4_NL / 2; ++j)
                acc += kvalues_iq4nl[x[ib + k].qs[j] & 0xf] * y[ib + k].qs[j] +
                       kvalues_iq4nl[x[ib + k].qs[j] >> 4] * y[ib + k].qs[j + QK4_NL / 2];
            s[k] = acc;
        }
        float X = ggml_fp16_to_fp32(x[ib].d) * ggml_fp16_to_fp32(y[ib].d);
        float Y = ggml_fp16_to_fp32(x[ib + 1].d) * ggml_fp16_to_fp32(y[ib + 1].d);
        keep_rounded(X);
        keep_rounded(Y);
        const float C = (float) s[0], F = (float) s[1];
        float t;
        if (form == 0) {
            float yf = Y * F;
            keep_rounded(yf);
            t = std::fma(X, C, yf);
        } else if (form == 1) {
            float a = X * C, b = Y * F;
            keep_rounded(a);
            keep_rounded(b);
            t = a + b;
        } else {
            float xc = X * C;
            keep_rounded(xc);
            t = std::fma(Y, F, xc);
        }
        keep_rounded(t);
        sumf = sumf + t;
    }
    return sumf;
}
#endif

}  // namespace

bool native_experts_available() noexcept { return true; }

// The "is this format handled by that kernel" questions, answered here and not next to the kernels: iq_avx512.cpp is
// compiled for AVX-512 and iq_avx2.cpp / kq_avx2.cpp for AVX2, and native_gu_rows asks these on every CPU before it
// has checked what the CPU can run.  A function in a wide-ISA file may use that ISA anywhere in its body, so an
// answer that is only a comparison must not come from one (#795).
bool iq512_supported(int type) noexcept {
    return type == 16 || type == 17 || type == 18 || type == 21 || type == 22;
}

bool iq256_supported(int type) noexcept {
    return type == 16 || type == 17 || type == 18 || type == 21 || type == 22 || type == 23;
}

bool kq256_supported(int type) noexcept { return type == 12 || type == 7 || type == 8; }

bool native_fmt(int gu_type, int d_type, int64_t n_embd, int64_t n_ff, NativeFmt& f, std::string& err, int layer) {
    init_once();
    const ggml_type_traits_cpu* tg = traits(gu_type);
    const ggml_type_traits_cpu* td = traits(d_type);
    if (tg == nullptr || tg->vec_dot == nullptr || td == nullptr || td->vec_dot == nullptr) {
        err = "native experts: ggml-cpu has no dot product for type " + std::to_string(tg && tg->vec_dot ? d_type : gu_type);
        return false;
    }
    const ggml_type_traits_cpu* ag = traits(tg->vec_dot_type);
    const ggml_type_traits_cpu* ad = traits(td->vec_dot_type);
    if (ag == nullptr || ag->from_float == nullptr || ad == nullptr || ad->from_float == nullptr) {
        err = "native experts: ggml-cpu cannot quantize an activation for this layer";
        return false;
    }
    if (n_embd % ggml_blck_size((ggml_type) gu_type) || n_ff % ggml_blck_size((ggml_type) d_type) ||
        n_embd % ggml_blck_size(tg->vec_dot_type) || n_ff % ggml_blck_size(td->vec_dot_type)) {
        err = "native experts: expert geometry is not whole blocks";
        return false;
    }
    f.gu_type = gu_type;
    f.d_type = d_type;
    f.gu_act = (int) tg->vec_dot_type;
    f.d_act = (int) td->vec_dot_type;
#ifdef STRATA_IQ3S_NEON_MT_BUILD
    if (gu_type == GGML_TYPE_IQ3_S) (void) iq3s_neon_mt_mode();   // its startup line, once
    (void) replica_check();
#endif
    const char* q8_1_probe = std::getenv("STRATA_NATIVE_CPU_Q8_1_DOT");
    if (q8_1_probe != nullptr && !q8_1_selector_known(q8_1_probe)) {
        err = "native experts: STRATA_NATIVE_CPU_Q8_1_DOT must be 0, 1, all, a supported GU/DOWN pair "
              "(optionally followed by @layer=N), or a comma-separated list of those selectors";
        return false;
    }
    if (q8_1_probe != nullptr && std::strcmp(q8_1_probe, "0") != 0 &&
        q8_1_selector_matches(q8_1_probe, gu_type, d_type, layer)) {
        f.gu_act = GGML_TYPE_Q8_1;
        f.d_act = GGML_TYPE_Q8_1;
    }
    const char* reciprocal_silu_layer = std::getenv("STRATA_NATIVE_CPU_Q8_1_RECIPROCAL_SILU_LAYER");
    const char* reciprocal_silu_expert = std::getenv("STRATA_NATIVE_CPU_Q8_1_RECIPROCAL_SILU_EXPERT");
    if (reciprocal_silu_layer != nullptr) {
        int selected_layer = -1;
        if (!parse_layer_selector(reciprocal_silu_layer, selected_layer)) {
            err = "native experts: STRATA_NATIVE_CPU_Q8_1_RECIPROCAL_SILU_LAYER must be a non-negative layer number";
            return false;
        }
        f.q8_1_reciprocal_silu = selected_layer == layer && f.gu_act == GGML_TYPE_Q8_1 &&
                                 f.d_act == GGML_TYPE_Q8_1;
    }
    if (reciprocal_silu_expert != nullptr &&
        !parse_layer_selector(reciprocal_silu_expert, f.q8_1_reciprocal_silu_expert)) {
        err = "native experts: STRATA_NATIVE_CPU_Q8_1_RECIPROCAL_SILU_EXPERT must be a non-negative expert number";
        return false;
    }
    const char* exp2f_silu_layer = std::getenv("STRATA_NATIVE_CPU_Q8_1_EXP2F_SILU_LAYER");
    const char* exp2f_silu_expert = std::getenv("STRATA_NATIVE_CPU_Q8_1_EXP2F_SILU_EXPERT");
    if (exp2f_silu_layer != nullptr) {
        int selected_layer = -1;
        if (!parse_layer_selector(exp2f_silu_layer, selected_layer)) {
            err = "native experts: STRATA_NATIVE_CPU_Q8_1_EXP2F_SILU_LAYER must be a non-negative layer number";
            return false;
        }
        f.q8_1_exp2f_silu = selected_layer == layer && f.gu_act == GGML_TYPE_Q8_1 &&
                            f.d_act == GGML_TYPE_Q8_1;
    }
    if (exp2f_silu_expert != nullptr &&
        !parse_layer_selector(exp2f_silu_expert, f.q8_1_exp2f_silu_expert)) {
        err = "native experts: STRATA_NATIVE_CPU_Q8_1_EXP2F_SILU_EXPERT must be a non-negative expert number";
        return false;
    }
    if (f.q8_1_exp2f_silu && f.q8_1_reciprocal_silu) {
        err = "native experts: exp2f and reciprocal SiLU probes cannot both select the same layer";
        return false;
    }
    f.n_embd = n_embd;
    f.n_ff = n_ff;
    f.gu_row = ggml_row_size((ggml_type) gu_type, n_embd);
    f.d_row = ggml_row_size((ggml_type) d_type, n_ff);
    f.up_off = f.gu_row * (size_t) n_ff;
    f.down_off = 2 * f.up_off;
    f.bytes = f.down_off + f.d_row * (size_t) n_embd;
    f.act_bytes = ggml_row_size((ggml_type) f.gu_act, n_embd);
    f.h_bytes = ggml_row_size((ggml_type) f.d_act, n_ff);
    if (f.act_bytes > kNativeActBytes || f.h_bytes > kNativeHBytes) {
        err = "native experts: activation larger than the pool's buffers";
        return false;
    }
    return true;
}

namespace {
// Q8_K (the activations of every i-quant row): ggml-cpu's x86 quantizer is the scalar reference, ~3 us per token
// and layer on the host before the pool can start; q8k_quant_avx2 writes the same bytes.  cpu_avx2_ok() too:
// iq_avx2.cpp is compiled for AVX2 (an AVX-only CPU, or STRATA_FORCE_ISA=avx, keeps ggml's).  STRATA_NO_Q8K_AVX2=1:
// ggml's on any CPU.
bool q8k_avx2(int type) {
    static const bool on = cpu_avx2_ok() && std::getenv("STRATA_NO_Q8K_AVX2") == nullptr;
    return on && type == (int) GGML_TYPE_Q8_K;
}
}  // namespace

void native_quant_act(const NativeFmt& f, const float* x, void* dst) {
    if (f.gu_act == GGML_TYPE_Q8_1) { quantize_q8_1_cuda_order(x, (int) f.n_embd, dst); return; }
#if STRATA_CPU_X86
    if (q8k_avx2(f.gu_act)) { q8k_quant_avx2(x, dst, f.n_embd); return; }
#endif
    traits(f.gu_act)->from_float(x, dst, f.n_embd);
#ifdef STRATA_IQ3S_NEON_MT_BUILD
    if (f.gu_act == GGML_TYPE_Q8_K && replica_check()) rc_q8k(x, dst, f.n_embd);
#endif
}

void native_quant_h(const NativeFmt& f, const float* h, void* dst) {
    if (f.d_act == GGML_TYPE_Q8_1) { quantize_q8_1_cuda_order(h, (int) f.n_ff, dst); return; }
#if STRATA_CPU_X86
    if (q8k_avx2(f.d_act)) { q8k_quant_avx2(h, dst, f.n_ff); return; }
#endif
    traits(f.d_act)->from_float(h, dst, f.n_ff);
#ifdef STRATA_IQ3S_NEON_MT_BUILD
    if (f.d_act == GGML_TYPE_Q8_0 && replica_check()) rc_q80(h, dst, f.n_ff);
#endif
}

int native_gu_mt_min(int gu_type) {
    // #152: from how many tokens the multi-token kernels run (ggml's vec_dot below that).  The default 2 is the
    // measured-fastest rule, but a token's expert rows then round differently alone than in a group, so greedy output
    // can depend on how many drafts a verify window held.  STRATA_IQ_MT_MIN=1 (opt-in, 0.1.30) uses the multi-token
    // kernels for every group: output independent of the drafting, at a measured -1..-3% decode on IQ3_S (AVX-512).
    static const char* env = std::getenv("STRATA_IQ_MT_MIN");
    static const int mt_min = env ? std::atoi(env) : 2;
    // IQ3_S where the AVX-2 kernel gathers its grid (cpu_gather_fast, unless STRATA_IQ256_GATHER=0) on a CPU without
    // AVX-512: there that kernel beats ggml's dot for ONE token too (14900KF P-core, an expert's gate/up rows: 0.34 ->
    // 0.19 ms; its E-cores, which keep the scalar decode: 0.71 -> 0.68), and in decode most CPU experts serve one token
    // of the window.  So IQ3_S takes it for every group, and those rows no longer depend on the drafting.  A machine-
    // wide rule, not a per-core one: every core rounds an expert the same.  Every probe here is in expert_layout.cpp
    // and cpu_avx2_ok() comes first, so no AVX2 code runs before the check.  STRATA_IQ_MT_MIN set keeps its rule.
    // Opt-in (STRATA_IQ3S_MT1=1): it changes a lone token's IQ3_S rounding on those CPUs, so the default stays 0.1.39's.
    static const bool iq3s_one = env == nullptr && std::getenv("STRATA_IQ3S_MT1") != nullptr && cpu_avx2_ok() && std::getenv("STRATA_NO_IQ256") == nullptr &&
                                 !cpu_avx512_ok() && iq256_gather_setting() != 0 && cpu_gather_fast();
    return iq3s_one && gu_type == 21 ? 1 : mt_min;
}

void native_gu_rows(const NativeFmt& f, const uint8_t* blob, const void* const* act, int nt, float* const* ff,
                    int r0, int r1, const uint8_t* up) {
    const uint8_t* const ub = up != nullptr ? up : blob + f.up_off;
    if (q8_1_scalar_dot(f)) {
        for (int r = r0; r < r1; ++r) {
            const uint8_t* gr = blob + (size_t) r * f.gu_row;
            const uint8_t* ur = ub + (size_t) r * f.gu_row;
            for (int t = 0; t < nt; ++t) {
                const auto* xq = (const uint8_t*) act[t];
                const auto dot = f.gu_type == GGML_TYPE_IQ2_S ? q8_1_iq2_s_cuda_dot :
                                 f.gu_type == GGML_TYPE_IQ3_XXS ? q8_1_iq3_xxs_cuda_dot : q8_1_iq3_s_cuda_dot;
                const float g = dot(gr, xq, (int) f.n_embd);
                const float u = dot(ur, xq, (int) f.n_embd);
                if (f.q8_1_exp2f_silu) {
                    constexpr float kLog2E = 1.4426950408889634f;
                    const float e = std::exp2((-g) * kLog2E);
                    ff[t][r] = (g / (1.f + e)) * u;
                } else if (f.q8_1_reciprocal_silu) {
                    const float sigmoid = 1.f / (1.f + std::exp(-g));
                    ff[t][r] = (g * sigmoid) * u;
                } else {
                    ff[t][r] = (g / (1.f + std::exp(-g))) * u;
                }
            }
        }
        return;
    }
    // the multi-token kernels decode the weights once for all tokens: 2.0-2.4x ggml-cpu at three tokens, no faster
    // at one (all are bound by the codebook lookups, ~5 GB/s per core), measured by native_expert_parity.  AVX-512
    // first, then the AVX-2 one (Zen 2/3, Intel 12th-14th gen).  STRATA_NO_IQ512 drops an AVX-512 CPU to the
    // AVX-2 kernel, STRATA_NO_IQ256 drops the AVX-2 kernel; ggml-cpu's single-token vec_dot is reached only with
    // both set (and on a CPU without AVX-512, STRATA_NO_IQ512 changes nothing).
#if STRATA_CPU_X86
    static const bool avx512 = cpu_avx512_ok() && std::getenv("STRATA_NO_IQ512") == nullptr;
    // STRATA_NO_IQ256 drops the AVX-2 kernel.  cpu_avx2_ok() is ALSO required: iq_avx2.cpp and kq_avx2.cpp
    // are compiled /arch:AVX2 and use AVX2 and FMA3, so calling them on a CPU without either is an
    // illegal instruction, not a slow path.  The gate sat next to `avx512` above, which does test
    // cpu_avx512_ok(), and that asymmetry is what let a pre-Haswell CPU reach iq256_gu_rows.
    // Without it this falls through to ggml-cpu's vec_dot below, which is compiled for whatever
    // baseline the build selected (AVX1 here) and covers the same types - IQ2_XXS and IQ2_S among
    // them.  That path loops over tokens itself, so it is correct for any `nt`, not just one.
    static const bool avx2 = cpu_avx2_ok() && std::getenv("STRATA_NO_IQ256") == nullptr;
    const int mt_min = native_gu_mt_min(f.gu_type);   // #152
    // Unsloth UD-Q4_K_XL's Q4_K gate/up: the multi-token kernel is bit-exact against ggml's per-token dot (any group
    // size, no #152 rule).  Opt-in, STRATA_KQ256=1: measured no faster in the engine (a window's expert groups hold
    // ~1.4 tokens and the weights stay in L1 across ggml's per-token calls; 1.01-1.13x in native_expert_parity).
    static const bool kq = [] { const char* v = std::getenv("STRATA_KQ256"); return cpu_avx2_ok() && v != nullptr && std::atoi(v) != 0; }();
    if (up == nullptr && kq && f.gu_type == 12 && nt >= 2) {   // one token: ggml's own dot below (the same bits, less overhead)
        kq256_gu_rows(f.gu_type, blob, f.gu_row, f.up_off, (int) f.n_embd, act, nt, ff, r0, r1);
        return;
    }
    // A format with only an AVX-2 kernel (IQ4_XS, #415) takes it on AVX-2 CPUs only: an AVX-512 CPU keeps ggml-cpu for
    // it, as before (its rows would round differently).  Each kernel only for the formats it implements: falling
    // through an empty switch would leave ff unwritten instead of falling back to ggml-cpu.
    static const bool cpu512 = cpu_avx512_ok();
    // these take the contiguous blob (up rows at up_off); split slices are aarch64-only (the dispatch), never here
    if (up == nullptr && nt >= mt_min && (iq512_supported(f.gu_type) || (!cpu512 && iq256_supported(f.gu_type)))) {
        if (avx512 && iq512_supported(f.gu_type)) {
            iq512_gu_rows(f.gu_type, blob, f.gu_row, f.up_off, (int) f.n_embd, act, nt, ff, r0, r1);
            return;
        }
        if (avx2 && iq256_supported(f.gu_type)) {
            iq256_gu_rows(f.gu_type, blob, f.gu_row, f.up_off, (int) f.n_embd, act, nt, ff, r0, r1);
            return;
        }
    }
#endif
#ifdef STRATA_IQ3S_NEON_MT_BUILD
    // one token keeps ggml's own dot (nothing to share); 2..MAXT tokens share each block's decode
    if (nt >= 2 && nt <= MAXT && f.gu_type == GGML_TYPE_IQ3_S && f.gu_act == GGML_TYPE_Q8_K) {
        if (const int mode = iq3s_neon_mt_mode(); mode != 0) {
            float g[MAXT], u[MAXT];
            for (int r = r0; r < r1; ++r) {
                iq3s_dot_mt(blob + (size_t) r * f.gu_row, act, nt, (int) f.n_embd, mode, g);
                iq3s_dot_mt(ub + (size_t) r * f.gu_row, act, nt, (int) f.n_embd, mode, u);
                for (int t = 0; t < nt; ++t) ff[t][r] = (g[t] / (1.f + std::exp(-g[t]))) * u[t];
            }
            return;
        }
    }
#endif
    const ggml_vec_dot_t dot = traits(f.gu_type)->vec_dot;
    const int n = (int) f.n_embd;
#ifdef STRATA_IQ3S_NEON_MT_BUILD
    const bool rc = f.gu_type == GGML_TYPE_IQ3_S && f.gu_act == GGML_TYPE_Q8_K && replica_check();
    unsigned long long rc_d[RC_FORMS] = {}, rc_e[RC_FORMS] = {}, rc_n = 0;
#endif
    for (int r = r0; r < r1; ++r) {
        const uint8_t* gr = blob + (size_t) r * f.gu_row;
        const uint8_t* ur = ub + (size_t) r * f.gu_row;
        for (int t = 0; t < nt; ++t) {
            float g = 0.f, u = 0.f;
            dot(n, &g, 0, gr, 0, act[t], 0, 1);
            dot(n, &u, 0, ur, 0, act[t], 0, 1);
            ff[t][r] = (g / (1.f + std::exp(-g))) * u;
#ifdef STRATA_IQ3S_NEON_MT_BUILD
            if (rc) {
                for (int m = 1; m <= 2; ++m) {
                    float rg = 0.f, ru = 0.f;
                    iq3s_dot_mt(gr, &act[t], 1, n, m, &rg);
                    iq3s_dot_mt(ur, &act[t], 1, n, m, &ru);
                    rc_d[m - 1] += (fbits(rg) == fbits(g)) + (fbits(ru) == fbits(u));
                }
                const uint32_t e = fbits(std::exp(-g));
                rc_e[0] += fbits(rep_expf(-g, true)) == e;
                rc_e[1] += fbits(rep_expf(-g, false)) == e;
                ++rc_n;
            }
#endif
        }
    }
#ifdef STRATA_IQ3S_NEON_MT_BUILD
    if (rc_n != 0) {
        rc_add(RC_EXP, rc_e, rc_n);
        rc_add(RC_IQ3S, rc_d, 2 * rc_n);
    }
#endif
}

void native_down_rows(const NativeFmt& f, const uint8_t* blob, const void* const* hq, int nt, float* const* out,
                      int r0, int r1, const uint8_t* down) {
    const uint8_t* const db = down != nullptr ? down : blob + f.down_off;
    if (q8_1_scalar_dot(f)) {
        for (int r = r0; r < r1; ++r) {
            const uint8_t* dr = db + (size_t) r * f.d_row;
            for (int t = 0; t < nt; ++t) {
                out[t][r] = f.d_type == GGML_TYPE_Q2_0
                    ? q8_1_q2_0_cuda_dot(dr, (const uint8_t*) hq[t], (int) f.n_ff)
                    : q8_1_iq4_nl_cuda_dot(dr, (const uint8_t*) hq[t], (int) f.n_ff);
            }
        }
        return;
    }
    // IQ4_NL down rows: the AVX-2 multi-token kernel decodes the nibbles and absolutises the weights once per
    // block instead of once per token; ggml-cpu's dot is single-token.  STRATA_NO_IQ4NL falls back to it.
#if STRATA_CPU_X86
    static const bool iq4nl_mt = std::getenv("STRATA_NO_IQ4NL") == nullptr;
    static const int mt_min = [] { const char* e = std::getenv("STRATA_IQ_MT_MIN"); return e ? std::atoi(e) : 2; }();
    static const bool kq = [] { const char* v = std::getenv("STRATA_KQ256"); return v != nullptr && std::atoi(v) != 0; }();
    // Both multi-token kernels below are /arch:AVX2 translation units (kq_avx2.cpp and iq_avx2.cpp),
    // so a CPU without AVX2 has to reach ggml-cpu's vec_dot instead - same reasoning as the gate/up
    // rows above, where `avx512` tested cpu_avx512_ok() and `avx2` did not.
    if (cpu_avx2_ok() && kq && nt >= 2 && (f.d_type == 7 || f.d_type == 8)) {   // Q5_1 / Q8_0 down: bit-exact, any group size
        kq256_rows(f.d_type, db, f.d_row, (int) f.n_ff, hq, nt, out, r0, r1);
        return;
    }
    if (cpu_avx2_ok() && nt >= mt_min && f.d_type == 20 && iq4nl_mt) {   // #152: the same rule as the gate/up rows
        iq4nl256_down_rows(db, f.d_row, (int) f.n_ff, hq, nt, out, r0, r1);
        return;
    }
#endif
    const ggml_vec_dot_t dot = traits(f.d_type)->vec_dot;
    const int n = (int) f.n_ff;
#ifdef STRATA_IQ3S_NEON_MT_BUILD
    const bool rc = f.d_type == GGML_TYPE_IQ4_NL && f.d_act == GGML_TYPE_Q8_0 && replica_check();
    unsigned long long rc_d[RC_FORMS] = {}, rc_n = 0;
#endif
    for (int r = r0; r < r1; ++r) {
        const uint8_t* dr = db + (size_t) r * f.d_row;
        for (int t = 0; t < nt; ++t) {
            float s = 0.f;
            dot(n, &s, 0, dr, 0, hq[t], 0, 1);
            out[t][r] = s;
#ifdef STRATA_IQ3S_NEON_MT_BUILD
            if (rc) {
                for (int m = 0; m < 3; ++m) rc_d[m] += fbits(rep_iq4nl(dr, hq[t], n, m)) == fbits(s);
                ++rc_n;
            }
#endif
        }
    }
#ifdef STRATA_IQ3S_NEON_MT_BUILD
    if (rc_n != 0) rc_add(RC_IQ4NL, rc_d, rc_n);
#endif
}

}  // namespace strata::kernels::cpu
