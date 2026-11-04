#!/bin/bash
# Engine-level probe, waited for: the Jetson's runner builds this source and runs the engine directly (not the server)
# on the fixed 4,096-token prompt with the base config + overrides + extra args; output in runs/<exp>/probe.txt.
# usage: ./ar_probe.sh EXP_ID overrides.json|- "extra engine args"
#   e.g. ./ar_probe.sh r3-p001-stats - "--max-new 64 --stats"
#   {RUN} in the args = this probe's Jetson folder (files written there come back to runs/<exp>/);
#   {RUNS} = the Jetson runs folder, to read a file an earlier probe wrote.
set -u
cd "$(dirname "$0")"
J=jetson; SRC=$HOME/workspace/strata-ar
. ./jrun.sh
EXP=$1; OVR=$2; EXTRA=$3
case "$EXP" in *[!A-Za-z0-9._-]*|"") echo "EXP_ID must be [A-Za-z0-9._-]"; exit 2;; esac
case "$EXP" in r3-*) ;; *) echo "EXP_ID must start with r3- (rounds 1-2 used the other names)"; exit 2;; esac
[ -e "runs/$EXP" ] && { echo "runs/$EXP exists: pick a new EXP_ID"; exit 2; }
mkdir -p "runs/$EXP"
if [ "$OVR" != "-" ]; then cp "$OVR" "runs/$EXP/overrides.json"; else echo '{}' > "runs/$EXP/overrides.json"; fi
EXTRA=${EXTRA//\{RUN\}//home/<user>/strata/ar/runs/$EXP}; EXTRA=${EXTRA//\{RUNS\}//home/<user>/strata/ar/runs}
jqueue 0 probe "$EXP" "runs/$EXP/overrides.json" "" "$EXTRA" || { echo "upload to the Jetson failed"; exit 3; }
jwait probe "$EXP" > "runs/$EXP/probe-tail.txt" 2>&1
scp -q "$J:strata/ar/detached/build-$EXP.log" "runs/$EXP/build.log" 2> /dev/null
grep -q '"build_fail"' "runs/$EXP/probe-tail.txt" && { echo "BUILD FAILED"; tail -30 "runs/$EXP/build.log"; exit 4; }
# every file the probe wrote comes back (telemetry excluded)
rsync -a --exclude memory.jsonl --exclude tegrastats.txt "$J:strata/ar/runs/$EXP/" "runs/$EXP/" 2>/dev/null
echo "probe $EXP: $EXTRA" >> runs/probes.log
tail -60 "runs/$EXP/probe.txt" 2>/dev/null || cat "runs/$EXP/probe-tail.txt"
