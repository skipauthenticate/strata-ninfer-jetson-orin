#!/bin/bash
# One autoresearch experiment, waited for: snapshot the source, queue it on the Jetson ahead of queued work, wait for
# the Jetson's runner to build and measure it, gate it, log a results.tsv row. The Mac sleeping only delays the
# result (the wait resumes on wake; a run whose ar_run.sh died is collected by the next ar_run.sh or ar_collect.sh).
# usage: ./ar_run.sh EXP_ID "short description" [overrides.json] [--needles]
#   overrides.json: {"args": {"--flag": "value" | true | null}, "env": {"NAME": "value"}}  (default: none)
set -u
cd "$(dirname "$0")"
J=jetson; SRC=$HOME/workspace/strata-ar
. ./jrun.sh
EXP=$1; DESC=$2; OVR=${3:--}; NEEDLES=""
[ "${4:-}" = "--needles" ] || [ "${3:-}" = "--needles" ] && NEEDLES=needles
[ "$OVR" = "--needles" ] && OVR=-
case "$EXP" in *[!A-Za-z0-9._-]*|"") echo "EXP_ID must be [A-Za-z0-9._-]"; exit 2;; esac
case "$EXP" in r3-*) ;; *) echo "EXP_ID must start with r3- (rounds 1-2 used the other names)"; exit 2;; esac
[ -e "runs/$EXP" ] && { echo "runs/$EXP exists: pick a new EXP_ID"; exit 2; }
collect_orphans
mkdir -p "runs/$EXP"
COMMIT=$(git -C "$SRC" rev-parse --short HEAD); DIRTY=$(git -C "$SRC" status --porcelain -- src include cmake CMakeLists.txt | wc -l | tr -d ' ')
git -C "$SRC" diff HEAD -- src include cmake CMakeLists.txt > "runs/$EXP/source.diff"
printf '%s\n%s\n' "$DESC" "$COMMIT+$DIRTY" > "runs/$EXP/meta.txt"
if [ "$OVR" != "-" ]; then cp "$OVR" "runs/$EXP/overrides.json"; else echo '{}' > "runs/$EXP/overrides.json"; fi
jqueue 0 bench "$EXP" "runs/$EXP/overrides.json" "$NEEDLES" "" || { echo "upload to the Jetson failed"; rm -rf "runs/$EXP"; exit 3; }
jwait bench "$EXP" > "runs/$EXP/result.json" 2> "runs/$EXP/bench.stderr"
finish "$EXP"
