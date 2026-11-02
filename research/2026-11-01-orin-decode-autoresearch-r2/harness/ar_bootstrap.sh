#!/bin/bash
# Round 2: baselines on the fast config (base-overrides.json on the Jetson), wait up to an hour for the research
# report, then the 8-hour loop.
cd "$(dirname "$0")"
log() { echo "$(date +%FT%T) $*" >> logs/loop.log; }
log "round 2 bootstrap: baselines"
for n in 1 2 3; do ./ar_run.sh r2-baseline-$n "round 2 baseline $n (fast config, ar build a94a322c)" >> logs/baselines.log 2>&1; done
./ar_run.sh r2-baseline-needles "round 2 baseline with 32K needles" --needles >> logs/baselines.log 2>&1
python3 compare.py runs/r2-baseline-1/result.json runs/r2-baseline-*/result.json >> logs/baselines.log 2>&1
for i in $(seq 1 60); do [ -s research-ideas.md ] && break; sleep 60; done
log "baselines done; research-ideas.md $( [ -s research-ideas.md ] && echo present || echo missing ); starting loop"
./ar_loop.sh 8
