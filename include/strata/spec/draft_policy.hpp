// include/strata/spec/draft_policy.hpp - per verify round: the MTP's window, or a lookup (suffix) window?
//
// The suffix drafter (prompt lookup) proposes the tokens that followed an earlier repeat of the context. Taken
// whenever it proposes more than the MTP, it lost 2-8% on ordinary text: a long lookup window costs much more to
// verify than the MTP's usual 3-4 tokens, and it is only worth that when enough of it is accepted. llama.cpp's
// lookup decoding answers the same problem with confidence thresholds on its n-gram statistics; here the policy
// learns both sides online and compares expected committed tokens per millisecond:
//
//   MTP     E = the mean tokens a window of that size has committed (EMA), at the measured cost of that size
//   lookup  E(k) = 1 + q + q^2 + ... + q^k for k <= the proposal, q = the acceptance rate of lookup drafts whose
//           match was about as long (4 buckets of match length, decayed counts), at the measured cost of k + 1
//
// and takes the lookup window only when its best E/cost beats the MTP's by `margin`. Costs are the measured round
// times per window size (EMA; sizes not seen yet are scaled from seen ones by a prior shape), so the policy adapts
// to the machine and the context length. It only chooses which drafts to verify: the output is unchanged.
#pragma once

#include <array>

namespace strata::spec {

class DraftPolicy {
public:
    static constexpr int kMaxT = 8;
    static constexpr int kBuckets = 4;

    explicit DraftPolicy(int max_t, double margin = 0.03);

    struct Pick {
        bool lookup = false;
        int t = 1;                      // window size (1 + drafts)
    };
    /// `t_mtp`: the MTP's window; `lookup_k`: the lookup proposal's length (0 = none); `match`: its match length.
    Pick choose(int t_mtp, int lookup_k, int match) const;
    /// After the round: the window it used, the drafts accepted, and the round's time (verify + commit + draft).
    void observe(bool lookup, int t, int accepted, int match, double round_ms);

    /// --lookup-chain: how many of `k_avail` lookup tokens to append after an MTP window of `t_mtp` tokens whose
    /// drafts all hold with probability `p_mtp` (estimated from the draft layer's own probabilities): the k with the
    /// best expected tokens per ms, E(t_mtp) + p_mtp (c + c^2 + .. + c^k) at the cost of t_mtp + k, if it beats the MTP
    /// window alone by `margin`; c = the acceptance of chained drafts by match length (their own counts). 0 = none.
    int chain(int t_mtp, double p_mtp, int k_avail, int match) const;
    /// After a chained round: the MTP window's size, the chained tokens, the window's accepted drafts, its time.
    void observe_chain(int t_mtp, int k, int accepted, int match, double round_ms);
    double chain_rate(int match) const;
    double lookup_rate(int match) const;   // current q for a match length
    double cost_ms(int t) const;           // measured or scaled round time of a window of t tokens

    /// ar STRATA_SPEC_COST=1 (opt-in; port of upstream 687810556 / 5f49ec459): the cost-aware MTP window. The chain is
    /// drafted one step at a time; after draft j (probability p_j)
    ///   E_j = 1 + q_0 + .. + q_j,  q_i = prod_{k<=i} a(p_k),  a() = the acceptance measured for MTP drafts of that probability
    /// is the expected tokens of the window of j + 2 rows, worth E_j / cost_ms(j + 2) tokens per ms. The window is the best
    /// width so far; the chain goes on only while one or two more drafts could still beat it. Window choice only: the
    /// verify window decides every token, so the output is unchanged.
    struct ChainState {
        double q = 1.0, e = 1.0, best_v = 0.0;
        int best_rows = 1;                 ///< the window to verify: 1 + the drafts kept
    };
    /// Draft `idx` (0-based, probability p) was just computed: update `st`, say whether to compute draft idx + 1.
    /// idx == 0 starts a new chain. `cap` = the widest window (rows).
    bool keep_draft(ChainState& st, int idx, float p, int cap) const;
    /// After an MTP window whose drafts came with p[0..n): `accepted` of them held. Teaches draft_rate().
    void observe_probs(const float* p, int n, int accepted);
    double draft_rate(double p) const;     // measured acceptance of an MTP draft that came with probability p
    /// Round ms of windows of 1..n rows, counted as `weight` rounds each (STRATA_SPEC_COST_TABLE); measurements replace it.
    void seed_costs(const double* ms, int n, double weight);
    /// Robust costs (STRATA_SPEC_COST): a round far above the known cost of its width (a graph capture, a stall) counts
    /// as at most twice that cost, and the first samples are a running mean. Off: the cost EMA as it always was.
    void set_robust(bool on) { robust_ = on; }
    /// ar STRATA_SPEC_STALE=N (opt-in): a width not measured for N rounds (default 300) is tried again, and that round
    /// replaces its price instead of moving the EMA a tenth of the way. A width priced in a slow stretch (the cache-cold
    /// first request of a workload) otherwise keeps its price for good: r3-e040's repetition requests 2-3 accepted
    /// every lookup draft yet ran T4 only, T6 still priced at request 1's 195 ms. SPEC_COST's chain probes stale widths too.
    void set_stale(double rounds) { stale_rounds_ = rounds; stale_reset_ = true; }

private:
    static int bucket(int match);
    double mtp_tokens(int t) const;
    bool stale(int t) const;               // a size not measured for a long stretch of rounds
    void add_cost(int t, double ms);       // one round time into the cost EMA of its width
    static constexpr int kPBuckets = 8;
    std::array<double, kPBuckets> pa_ok_{}, pa_n_{};       // MTP drafts accepted / reached by probability bucket (decayed)
    bool robust_ = false;
    // A size not measured for this many rounds is tried again when a confident lookup could use it: its cost was set in
    // one stretch (a prompt's cache refill, say) and, priced high, it would never be measured again (#1252)
    double stale_rounds_ = 300.0;
    bool stale_reset_ = false;             // set_stale: a stale width's next round replaces its price

    int max_t_;
    double margin_;
    std::array<double, kMaxT + 1> cost_{}, cost_n_{};      // round ms by window size
    std::array<double, kMaxT + 1> mtp_tok_{}, mtp_n_{};    // tokens committed by MTP windows of that size
    std::array<double, kBuckets> ok_{}, bad_{};            // lookup drafts accepted / windows cut short, decayed
    std::array<double, kBuckets> cok_{}, cbad_{};          // chained lookup drafts, the same (reached rounds only)
    double rounds_ = 0;                                    // rounds observed so far
    std::array<double, kMaxT + 1> last_{};                 // the round at which each size was last measured
};

}  // namespace strata::spec
