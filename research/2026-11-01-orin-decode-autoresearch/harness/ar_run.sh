#!/bin/bash
# One autoresearch experiment: sync source -> Jetson, incremental build, measure, gate, log a results.tsv row.
# usage: ./ar_run.sh EXP_ID "short description" [overrides.json] [--needles]
#   overrides.json: {"args": {"--flag": "value" | true | null}, "env": {"NAME": "value"}}  (default: none)
set -u
cd "$(dirname "$0")"
EXP=$1; DESC=$2; OVR=${3:--}; NEEDLES=""
[ "${4:-}" = "--needles" ] || [ "${3:-}" = "--needles" ] && NEEDLES=needles
[ "$OVR" = "--needles" ] && OVR=-
J=jetson; SRC=$HOME/workspace/strata-ar
case "$EXP" in *[!A-Za-z0-9._-]*|"") echo "EXP_ID must be [A-Za-z0-9._-]"; exit 2;; esac
[ -e "runs/$EXP" ] && { echo "runs/$EXP exists: pick a new EXP_ID"; exit 2; }
mkdir -p "runs/$EXP"
COMMIT=$(git -C "$SRC" rev-parse --short HEAD); DIRTY=$(git -C "$SRC" status --porcelain -- src include cmake CMakeLists.txt | wc -l | tr -d ' ')
git -C "$SRC" diff HEAD -- src include cmake CMakeLists.txt > "runs/$EXP/source.diff"
rsync -a --delete "$SRC/src/" "$J:strata/ar/src/src/" && rsync -a --delete "$SRC/include/" "$J:strata/ar/src/include/" \
  && rsync -a --delete "$SRC/cmake/" "$J:strata/ar/src/cmake/" && rsync -a "$SRC/CMakeLists.txt" "$J:strata/ar/src/CMakeLists.txt" \
  || { echo "rsync failed"; exit 3; }
if ! ssh "$J" 'bash ~/strata/ar/build.sh' > "runs/$EXP/build.log" 2>&1; then
  echo "BUILD FAILED (runs/$EXP/build.log):"; tail -30 "runs/$EXP/build.log"
  printf '%s\t%s\t%s\t%s+%s\tbuild_fail\t\t\t\t\t\t\t\t\t\t\t\t\n' "$EXP" "$(date +%FT%T)" "$DESC" "$COMMIT" "$DIRTY" >> results.tsv
  exit 4
fi
if [ "$OVR" != "-" ]; then cp "$OVR" "runs/$EXP/overrides.json"; else echo '{}' > "runs/$EXP/overrides.json"; fi
scp -q "runs/$EXP/overrides.json" "$J:strata/ar/overrides-$EXP.json"
ssh -o ServerAliveInterval=30 "$J" "timeout 7200 bash ~/strata/ar/bench.sh $EXP /home/<user>/strata/ar/build/strata /home/<user>/strata/ar/overrides-$EXP.json $NEEDLES" > "runs/$EXP/result.json" 2> "runs/$EXP/bench.stderr"
scp -q "$J:strata/ar/runs/$EXP/engine.log" "runs/$EXP/engine.log" 2>/dev/null
scp -q "$J:strata/ar/runs/$EXP/args.txt" "runs/$EXP/args.txt" 2>/dev/null
BASES=$(ls runs/baseline-*/result.json 2>/dev/null | grep -v "runs/$EXP/")
GATE=$(python3 compare.py "runs/$EXP/result.json" $BASES 2>/dev/null || echo '{}')
echo "$GATE" > "runs/$EXP/gate.json"
python3 - "$EXP" "$DESC" "$COMMIT+$DIRTY" "runs/$EXP/result.json" "runs/$EXP/gate.json" <<'PY' | tee -a results.tsv
import json, sys, datetime
exp, desc, commit, rp, gp = sys.argv[1:6]
try: r = json.load(open(rp))
except Exception: r = {"status": "no_result_json"}
g = json.load(open(gp)) if open(gp).read().strip() else {}
cols = [exp, datetime.datetime.now().isoformat(timespec="seconds"), desc, commit, r.get("status"),
        r.get("decode_med"), r.get("decode_min"), r.get("decode_max"), r.get("prefill_med"), r.get("ttft_med"),
        r.get("min_avail_gib"), r.get("hit_rate_last"), r.get("cache_slots"), g.get("agreement_min"), r.get("needles", ""),
        r.get("exe_sha256"), "; ".join(r.get("engine_errors") or [])[:200]]
print("\t".join("" if c is None else str(c) for c in cols))
PY
python3 -c "import json,sys; r=json.load(open(sys.argv[1])); r.pop('texts',None); print(json.dumps(r)[:900])" "runs/$EXP/result.json" 2>/dev/null
echo "gate: $GATE"
