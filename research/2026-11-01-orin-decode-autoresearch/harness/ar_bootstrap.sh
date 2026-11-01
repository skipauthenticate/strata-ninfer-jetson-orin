#!/bin/bash
# Waits for the community runs on the Jetson, builds the autoresearch engine, captures a warm expert profile with
# the adaptive tier on (one run), then fixes every later run to that profile with adaptation off
# (~/strata/ar/base-overrides.json: stationary cache, and no adaptive swaps near the memory floor), measures the
# baseline three times (separate server starts) plus 32K needles, and runs the 8-hour loop.
cd "$(dirname "$0")"
J=jetson
log() { echo "$(date +%FT%T) $*" >> logs/loop.log; }
log "bootstrap: waiting for the community runs"
until ssh -o ConnectTimeout=15 $J 'grep -q "long done" ~/strata/long.log' 2>/dev/null; do sleep 60; done
log "building"
ssh $J 'rm -f ~/strata/ar/base-overrides.json ~/strata/ar/warm-profile.bin; bash ~/strata/ar/build.sh' > logs/initial-build.log 2>&1 \
  || { log "initial build failed (logs/initial-build.log)"; exit 1; }
./ar_run.sh warmup-profile "adaptive warm-up; saves the warm expert profile" overrides/warmup-profile.json >> logs/baselines.log 2>&1
if ssh $J 'test -s ~/strata/ar/warm-profile.bin'; then
  ssh $J 'echo "{\"args\": {\"--expert-profile\": \"/home/<user>/strata/ar/warm-profile.bin\", \"--adapt-every\": \"100000\"}}" > ~/strata/ar/base-overrides.json'
  log "warm profile saved; base: warm profile + --adapt-every 100000"
else
  ssh $J 'echo "{\"args\": {\"--adapt-every\": \"100000\"}}" > ~/strata/ar/base-overrides.json'
  log "warm profile NOT saved; base: setup profile + --adapt-every 100000"
fi
ssh $J 'cat ~/strata/ar/base-overrides.json' > base-overrides.json
for n in 1 2 3; do ./ar_run.sh baseline-$n "baseline run $n (base config, ar build)" >> logs/baselines.log 2>&1; done
./ar_run.sh baseline-needles "baseline with 32K needles" --needles >> logs/baselines.log 2>&1
python3 compare.py runs/baseline-1/result.json runs/baseline-*/result.json >> logs/baselines.log 2>&1
log "baselines done; starting loop"
./ar_loop.sh 8
