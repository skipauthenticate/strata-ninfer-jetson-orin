#!/bin/bash
# Engine-level probe: sync source -> Jetson, build, run the engine directly (not the server) on the fixed
# 4,096-token prompt with the base config + overrides + extra args; output in runs/<exp>/probe.txt.
# usage: ./ar_probe.sh EXP_ID overrides.json|- "extra engine args"
#   e.g. ./ar_probe.sh p001-stats - "--max-new 64 --stats"
#        ./ar_probe.sh p002-gpu-floor - "--max-new 16 --gpu-only-full --stats"
#   {RUN} in the args = this probe's Jetson folder (files written there come back to runs/<exp>/);
#   {RUNS} = the Jetson runs folder, to read a file an earlier probe wrote.
set -u
cd "$(dirname "$0")"
EXP=$1; OVR=$2; EXTRA=$3
J=jetson; SRC=$HOME/workspace/strata-ar
case "$EXP" in *[!A-Za-z0-9._-]*|"") echo "EXP_ID must be [A-Za-z0-9._-]"; exit 2;; esac
[ -e "runs/$EXP" ] && { echo "runs/$EXP exists: pick a new EXP_ID"; exit 2; }
mkdir -p "runs/$EXP"
rsync -a --delete "$SRC/src/" "$J:strata/ar/src/src/" && rsync -a --delete "$SRC/include/" "$J:strata/ar/src/include/" \
  && rsync -a --delete "$SRC/cmake/" "$J:strata/ar/src/cmake/" && rsync -a "$SRC/CMakeLists.txt" "$J:strata/ar/src/CMakeLists.txt" || exit 3
ssh "$J" 'bash ~/strata/ar/build.sh' > "runs/$EXP/build.log" 2>&1 || { echo "BUILD FAILED"; tail -30 "runs/$EXP/build.log"; exit 4; }
if [ "$OVR" != "-" ]; then cp "$OVR" "runs/$EXP/overrides.json"; else echo '{}' > "runs/$EXP/overrides.json"; fi
scp -q "runs/$EXP/overrides.json" "$J:strata/ar/overrides-$EXP.json"
# {RUN} = this probe's folder on the Jetson, {RUNS} = all run folders (e.g. {RUNS}/p002-ref/cont.ids)
EXTRA=${EXTRA//\{RUN\}//home/<user>/strata/ar/runs/$EXP}; EXTRA=${EXTRA//\{RUNS\}//home/<user>/strata/ar/runs}
ssh -o ServerAliveInterval=30 "$J" "timeout 7200 bash ~/strata/ar/probe.sh $EXP /home/<user>/strata/ar/build/strata /home/<user>/strata/ar/overrides-$EXP.json '$EXTRA'" > "runs/$EXP/probe-tail.txt" 2>&1
# every file the probe wrote comes back (telemetry excluded)
rsync -a --exclude memory.jsonl --exclude tegrastats.txt "$J:strata/ar/runs/$EXP/" "runs/$EXP/" 2>/dev/null
echo "probe $EXP: $EXTRA" >> runs/probes.log
tail -60 "runs/$EXP/probe.txt" 2>/dev/null || cat "runs/$EXP/probe-tail.txt"
