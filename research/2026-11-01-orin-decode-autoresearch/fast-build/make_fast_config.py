#!/usr/bin/env python3
"""strata-iq3_s-fast.json from setup's strata-iq3_s.json: the decode-speed engine and the overnight best settings
(e096), without the two diagnostic switches (STRATA_DECODE_TIMING, STRATA_BW_PROBE). With a draft-head GGUF (4th
argument, mtp-q8_0.gguf), also round 2's best settings (r2-e043) and round 3's (r3-e118).
usage: make_fast_config.py <strata folder> <engine> <profile.bin> [<mtp-q8_0.gguf>]"""
import json
import sys
from pathlib import Path

repo, engine, profile = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
draft_head = sys.argv[4] if len(sys.argv) > 4 else None
cfg = json.loads((repo / "strata-iq3_s.json").read_text())
args, pairs, i = cfg["args"], [], 0
while i < len(args):
    if i + 1 < len(args) and not args[i + 1].startswith("--"):
        pairs.append([args[i], args[i + 1]]); i += 2
    else:
        pairs.append([args[i], None]); i += 1
set_ = {"--expert-profile": profile, "--adapt-every": "100000", "--kv-grow": None, "--expert-cache": "14629",
        "--mtp-hnorm": "stream"}
if draft_head:
    set_["--pool-workers"] = "9"  # round 3: 9 CPU workers for expert misses, pinned with STRATA_POOL_SIBLINGS
pairs = [p for p in pairs if p[0] not in set_] + [[k, v] for k, v in set_.items()]
cfg["args"] = [x for p in pairs for x in p if x is not None]
cfg["exe"] = engine
cfg["log"] = str(repo / "strata-iq3_s-fast.log")
cfg["model_name"] = "qwen3.8-flash-next-iq3_s"
cfg["env"] = {"STRATA_GR_FAST": "1", "STRATA_DRAFT_VOCAB_TOP": "40960",
              "STRATA_MMVQ_IL_ROWS": "14:2:0,1,1,1,2;14:3:0,1,1,1,2;14:4:0,1,1,1,2", "STRATA_VRAM_GY": "8",
              "STRATA_GR_UP_LR": "1", "STRATA_MMVQ1_WARP": "1", "STRATA_NO_PCIE": "1", "STRATA_HIT_COMBINE": "1",
              "STRATA_ATTN_PRE75": "1", "STRATA_EXP_PF": "1", "STRATA_HC_DOWN_WPB": "21", "STRATA_HC_UP_PF": "48"}
if draft_head:
    cfg["env"].update({"STRATA_SPEC_CUM": "0,0.40,0.47", "STRATA_IO_PREFETCH": "1", "STRATA_MTP_EXPERTS": draft_head,
                       "STRATA_MTP_EXPERTS_AS": "iq4_xs", "STRATA_HC_DOWN_RR": "1",
                       # round 3
                       "STRATA_MISS_ZEROCOPY": "1", "STRATA_SPEC_COST": "1",
                       "STRATA_SPEC_COST_TABLE": "52.5,63.5,74.5,86.7", "STRATA_POOL_SIBLINGS": "1"})
(repo / "strata-iq3_s-fast.json").write_text(json.dumps(cfg, indent=1) + "\n")
print(" ".join(cfg["args"]))
