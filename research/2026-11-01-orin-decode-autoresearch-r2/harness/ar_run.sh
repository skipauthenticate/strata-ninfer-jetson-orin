#!/bin/bash
# One autoresearch experiment: sync source -> Jetson, incremental build, measure, gate, log a results.tsv row.
# The Jetson steps run detached (jrun.sh): if the Mac sleeps, the measurement carries on and its result is read on
# wake, or by the next ar_run.sh if this one died.
# usage: ./ar_run.sh EXP_ID "short description" [overrides.json] [--needles]
#   overrides.json: {"args": {"--flag": "value" | true | null}, "env": {"NAME": "value"}}  (default: none)
set -u
cd "$(dirname "$0")"
EXP=$1; DESC=$2; OVR=${3:--}; NEEDLES=""
[ "${4:-}" = "--needles" ] || [ "${3:-}" = "--needles" ] && NEEDLES=needles
[ "$OVR" = "--needles" ] && OVR=-
J=jetson; SRC=$HOME/workspace/strata-ar
. ./jrun.sh
case "$EXP" in *[!A-Za-z0-9._-]*|"") echo "EXP_ID must be [A-Za-z0-9._-]"; exit 2;; esac
case "$EXP" in r2-*) ;; *) echo "EXP_ID must start with r2- (round 1 used the other names)"; exit 2;; esac
[ -e "runs/$EXP" ] && { echo "runs/$EXP exists: pick a new EXP_ID"; exit 2; }
collect_orphans
mkdir -p "runs/$EXP"
COMMIT=$(git -C "$SRC" rev-parse --short HEAD); DIRTY=$(git -C "$SRC" status --porcelain -- src include cmake CMakeLists.txt | wc -l | tr -d ' ')
git -C "$SRC" diff HEAD -- src include cmake CMakeLists.txt > "runs/$EXP/source.diff"
printf '%s\n%s\n' "$DESC" "$COMMIT+$DIRTY" > "runs/$EXP/meta.txt"
jsync || { echo "rsync failed"; touch "runs/$EXP/done"; exit 3; }
if ! jrun "build-$EXP" bash /home/<user>/strata/ar/build.sh > "runs/$EXP/build.log" 2>&1; then
  echo "BUILD FAILED (runs/$EXP/build.log):"; tail -30 "runs/$EXP/build.log"
  printf '%s\t%s\t%s\t%s+%s\tbuild_fail\t\t\t\t\t\t\t\t\t\t\t\t\n' "$EXP" "$(date +%FT%T)" "$DESC" "$COMMIT" "$DIRTY" >> results.tsv
  touch "runs/$EXP/done"; exit 4
fi
if [ "$OVR" != "-" ]; then cp "$OVR" "runs/$EXP/overrides.json"; else echo '{}' > "runs/$EXP/overrides.json"; fi
scp -q "runs/$EXP/overrides.json" "$J:strata/ar/overrides-$EXP.json"
jrun "bench-$EXP" timeout 7200 bash /home/<user>/strata/ar/bench.sh "$EXP" /home/<user>/strata/ar/build/strata \
  "/home/<user>/strata/ar/overrides-$EXP.json" $NEEDLES > "runs/$EXP/result.json" 2> "runs/$EXP/bench.stderr"
finish "$EXP"
