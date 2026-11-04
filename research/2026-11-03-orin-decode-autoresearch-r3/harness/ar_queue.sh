#!/bin/bash
# Queue one experiment on the Jetson and return at once: snapshot the source and the overrides, write the job. The
# Jetson's runner builds and measures queued jobs one at a time, in order, with no Mac needed; ./ar_collect.sh (and
# every ar_run.sh) logs the finished ones in results.tsv. Several ar_queue.sh calls in a row = a batch.
# usage: ./ar_queue.sh EXP_ID "short description" [overrides.json] [--needles]
set -u
cd "$(dirname "$0")"
J=jetson; SRC=$HOME/workspace/strata-ar
. ./jrun.sh
EXP=$1; DESC=$2; OVR=${3:--}; NEEDLES=""
[ "${4:-}" = "--needles" ] || [ "${3:-}" = "--needles" ] && NEEDLES=needles
[ "$OVR" = "--needles" ] && OVR=-
case "$EXP" in *[!A-Za-z0-9._-]*|"") echo "EXP_ID must be [A-Za-z0-9._-]"; exit 2;; esac
case "$EXP" in r3-*) ;; *) echo "EXP_ID must start with r3-"; exit 2;; esac
[ -e "runs/$EXP" ] && { echo "runs/$EXP exists: pick a new EXP_ID"; exit 2; }
# backpressure (owner, 22:05): the Jetson drains ~10 benches an hour; past 12 pending, results arrive hours after they are queued
P=$(ssh -o ConnectTimeout=20 "$J" 'ls ~/strata/ar/queue/pending 2>/dev/null | grep -c .job')
[ "${P:-0}" -ge 12 ] && { echo "queue full: $P pending (cap 12, ~1 h of Jetson time). Not queued. Judge what is already queued (./ar_collect.sh), commit code as PENDING, and queue it in a later iteration."; exit 4; }
mkdir -p "runs/$EXP"
COMMIT=$(git -C "$SRC" rev-parse --short HEAD); DIRTY=$(git -C "$SRC" status --porcelain -- src include cmake CMakeLists.txt | wc -l | tr -d ' ')
git -C "$SRC" diff HEAD -- src include cmake CMakeLists.txt > "runs/$EXP/source.diff"
printf '%s\n%s\n' "$DESC" "$COMMIT+$DIRTY" > "runs/$EXP/meta.txt"
if [ "$OVR" != "-" ]; then cp "$OVR" "runs/$EXP/overrides.json"; else echo '{}' > "runs/$EXP/overrides.json"; fi
jqueue 1 bench "$EXP" "runs/$EXP/overrides.json" "$NEEDLES" "" || { echo "upload to the Jetson failed"; rm -rf "runs/$EXP"; exit 3; }
echo "queued $EXP (source $COMMIT+$DIRTY); $(ssh "$J" 'ls ~/strata/ar/queue/pending | wc -l') waiting in the queue"
