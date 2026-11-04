# Autoresearch round 3: IQ3_S decode on a Jetson AGX Orin 64 GB, three workloads, lossless

You are one iteration of an unattended research loop. A fresh agent runs this file again after you exit; everything
you learn must be written to files. Read, in order: `notes.md` (this round; its top says what is current and what is
PENDING), `PLAN.md` and `research/plan-review.md` (the ranked plan and its corrections), the last rows of
`results.tsv`, and the research reports in `research/` as needed (gufo.md, upstream-strata.md, engines-and-papers.md).
Round 2's log is `~/workspace/strata-ar-lab-r2/notes.md`. **First command of every iteration:
`./ar_collect.sh`** (it logs runs that finished while no agent was watching). Then do one item, record it, stop.

## Goal
Raise single-request **decode tok/s** of Qwen3.8-Flash-Next **IQ3_S at a 262,144-token context**. Every bench measures
three workloads in one server session, 3 fresh 4,096-token prompts x 256 greedy tokens each: **review** (the community
benchmark: the headline number, `decode_med`), **prose** and **repetition** (gufo's two workloads: `prose_med`,
`rep_med`, and their mean `pr_mean`). The owner's target is +150% (>= 87.5 tok/s); the research (PLAN.md section 0)
puts review's realistic landing far lower. Report every workload honestly; never substitute one for another.

## Where the time goes (review; round 2 cost model, see CONTEXT.md)
A verify window costs ~37 ms fixed + ~11.5 ms per column at T2-T4 and ~25 ms for a 5th column (dense IL kernels at 5
columns: a cliff). Per column: experts +5.4, dense +2.0, HC +1.2, shared/attention ~+1.2 ms. Fixed: dense ~19-22, HC
~11.6-15, head ~5 ms. Drafts are good (90/78/85% per depth); the column price, not the drafter, caps tokens per
window. **Prose and repetition are expert-cache-miss-bound** until the cache profile covers them (77-90% hits vs
99.9% on review; repetition drafts are all accepted yet it runs at ~15 tok/s off the SSD): see notes.md for the
profile status before judging anything on those two.

## Rules (hard)
1. **Lossless only.** No lower precision for weights, KV or activations than the base; no dropped, pruned or skipped
   experts; no change to routing, top-k, sampling, attention math or model files. Allowed: memory placement, caching
   and cache profiles, scheduling, overlap, kernels computing the same math, graph capture, threads, drafting and
   verification policy (drafts are verified exactly), build flags that keep the math.
2. **Fixed by design** (the harness refuses overrides of them): `--max-context 262144`, `--kv int8`, `--pack`,
   `--native`, `--ple-gguf`. The base keeps the adaptive tier off (`--adapt-every 100000`); testing it is allowed (Phase A6: `--adapt-every` 16 /
   64 / 256): it changes placement only. A text change with matching cache slots is REVIEW (explain it), not FAIL;
   watch for GPU resets and `pressure_abort`.
3. **Gate.** PASS = status `ok` and `agreement_min` 1.0: identical text on all nine prompts (review, prose and
   repetition) against the baselines listed in `gate-baselines.txt`. Status `ok_slots_drift` means the expert cache
   came up a different size (free memory at start), which changes text on its own: re-run it, do not judge it.
   `partial` = a workload did not finish: never a PASS. A change that alters arithmetic order is REVIEW (notes.md,
   with the argument); prove what you can with `./ar_probe.sh` (`--spec-follow` + `--window-hashes`). Run
   `--needles` (32K, 3/3) once on anything you would keep.
4. **Improvement**: better only if `decode_med` beats the current best by more than the baselines' spread and a
   repeat confirms it. 2 of 15 review requests stall (PLE/SSD, ~15-23 tok/s): never decide on a single run's minimum.
5. **Allowed actions only** (enforced): edit files under `~/workspace/strata-ar/{src,include,cmake,CMakeLists.txt}`,
   `notes.md`, `research-ideas.md`, `overrides/*.json`, `TARGET_MET`; run `./ar_run.sh`, `./ar_queue.sh`,
   `./ar_collect.sh`, `./ar_probe.sh`, `python3 compare.py`, local `git -C ~/workspace/strata-ar ...` (no
   push), read-only shell tools. Read anything (the engine clones in `~/workspace/research-engines/` are read-only
   data: read them, never build or run them). No ssh: the harness does all Jetson work.
6. **Experiment ids start with `r3-`** (`r3-e001-slug` for runs, `r3-p001-slug` for probes), numbered after the last
   one used in results.tsv / runs/.
7. **Commits**: commit every kept or REVIEW change on branch `ar/decode-speed` with a message that starts with the
   review decode median (`decode 37.4 tok/s: ...`), says what changed in plain words, and names the evidence (exp
   ids, workloads, texts identical or REVIEW, needles). No Co-Authored-By or other attribution lines. New behavior
   stays opt-in (an env switch or flag) so the default engine is unchanged.
8. **Hand-off.** A kernel item usually does not finish building and measuring inside one iteration. Before you exit
   with runs still queued: commit the work as `PENDING r3-eXXX: <what>` (opt-in, default off), and write in notes.md
   which exp ids to collect and what decides keep or revert. Never revert source that an uncollected run measured:
   each run's exact source is also in `runs/<exp>/source.diff` (`git apply` it to restore). Revert everything else
   with `git -C ~/workspace/strata-ar checkout -- src include cmake CMakeLists.txt`. A build that fails
   twice: revert, note it, move on.
9. **Budget**: about 60 minutes and 250 turns per iteration; do not spend turns polling: queue, work on the next
   item, and collect once near the end. A kernel iteration is one build plus up to 3 override variants; a
   settings iteration can queue up to 8 runs.

## How to run
```bash
./ar_collect.sh                                   # log finished queued runs, show the queue (always first)
# queue a batch on one source state and keep working; the Jetson builds and measures them in order:
./ar_queue.sh r3-e012-minp085 "spec-min-p 0.85" overrides/r3-e012-minp085.json
./ar_queue.sh r3-e013-minp07 "spec-min-p 0.7" overrides/r3-e013-minp07.json
# one run, waited for (goes ahead of queued work):
./ar_run.sh r3-e014-confirm "e012 again, with needles" overrides/r3-e012-minp085.json --needles
# engine-level probe (no server) on the fixed 4,096-token review prompt; {RUN} = this probe's Jetson folder:
./ar_probe.sh r3-p020-stats - "--max-new 64 --stats"
```
Overrides: `{"args": {"--flag": "value" | true | null}, "env": {"NAME": "value"}}`, applied after the base
(`base-overrides.json`, already on the Jetson). `"STRATA_DECODE_TIMING": "1"` adds per-window-size timing, and
`"STRATA_VERIFY_PROFILE": "1"` the per-stage table, to engine.log (`runs/<exp>/engine.log`). A bench takes ~6 min (~11
with needles), plus the build when the source changed (a kernel file can take many minutes).

## Record keeping (every iteration)
- Append to `notes.md`: what you tried, numbers per workload, conclusion, ranked next steps; keep its top block
  current (current best per workload with exp id, commit and overrides; PENDING items and how to judge them).
- If a PASS change reaches 87.5 tok/s on review and passed `--needles`, write `TARGET_MET` with its exp id and stop.
