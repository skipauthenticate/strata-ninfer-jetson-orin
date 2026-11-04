#!/bin/bash
# Experiment queue on the Jetson: the only place that builds and measures. Jobs are files in ~/strata/ar/queue/pending
# (written by the Mac's ar_queue.sh / ar_run.sh / ar_probe.sh), taken in name order ("0-" direct runs before "1-"
# queued ones). Each job: copy its source snapshot (~/strata/ar/jobsrc/EXP) into the build tree, build, then bench.sh
# or probe.sh; output in ~/strata/ar/detached/{bench,probe}-EXP.{out,err,rc} (+ build-EXP.log), which the Mac reads.
# No Mac needed while it runs. One runner at a time (runner.lock). Stop after the current job: touch queue/STOP.
set -u
A=$HOME/strata/ar; Q=$A/queue; D=$A/detached
mkdir -p "$Q/pending" "$Q/running" "$Q/done" "$D"
exec 8> "$Q/runner.lock"; flock -n 8 || { echo "a queue runner is already active"; exit 0; }
log() { echo "$(date -Is) $*" >> "$Q/runner.log"; }
field() { sed -n "s/^$1=//p" "$2"; }
log "runner start (pid $$)"
while [ ! -e "$Q/STOP" ]; do
  job=$(ls "$Q"/pending/*.job 2> /dev/null | sort | head -1)
  [ -z "$job" ] && { sleep 10; continue; }
  n=$(basename "$job" .job); j="$Q/running/$n.job"; mv "$job" "$j"
  EXP=$(field EXP "$j"); KIND=$(field KIND "$j"); OVR=$(field OVR "$j"); NEEDLES=$(field NEEDLES "$j")
  EXTRA=$(field EXTRA64 "$j" | base64 -d 2> /dev/null)
  case "$EXP" in r3-*) ;; *) log "skip $n: bad EXP '$EXP'"; mv "$j" "$Q/done/"; continue;; esac
  case "$KIND" in bench|probe) ;; *) log "skip $n: bad KIND '$KIND'"; mv "$j" "$Q/done/"; continue;; esac
  O="$D/$KIND-$EXP"; S="$A/jobsrc/$EXP"
  log "start $KIND $EXP"
  ok=1
  # copy by content, not by time: a file that differs gets a fresh mtime so ninja rebuilds it, an unchanged file keeps
  # its mtime. (rsync -a kept the Mac's mtimes, so an older source state queued after a newer build never recompiled.)
  for d in src include cmake; do rsync -rlpD --checksum --delete "$S/$d/" "$A/src/$d/" || ok=0; done
  rsync -lpD --checksum "$S/CMakeLists.txt" "$A/src/CMakeLists.txt" || ok=0
  if [ $ok = 1 ] && bash "$A/build.sh" > "$D/build-$EXP.log" 2>&1; then
    if [ "$KIND" = bench ]; then
      timeout 7200 bash "$A/bench.sh" "$EXP" "$A/build/strata" "$OVR" $NEEDLES > "$O.out" 2> "$O.err" < /dev/null
    else
      timeout 7200 bash "$A/probe.sh" "$EXP" "$A/build/strata" "$OVR" "$EXTRA" > "$O.out" 2> "$O.err" < /dev/null
    fi
    rc=$?
  else
    echo '{"status": "build_fail"}' > "$O.out"; : > "$O.err"; rc=4
  fi
  if grep -qE '"status": "(lock_timeout|pressure_abort)"' "$O.out" 2> /dev/null && ! grep -q '^RETRIED=1' "$j"; then
    log "requeue $KIND $EXP once ($(grep -oE 'lock_timeout|pressure_abort' "$O.out" | head -1))"
    echo RETRIED=1 >> "$j"; mv "$j" "$Q/pending/$n.job"; continue   # keeps its source snapshot
  fi
  echo $rc > "$O.rc.tmp"; mv "$O.rc.tmp" "$O.rc"
  log "end $KIND $EXP rc $rc"
  mv "$j" "$Q/done/"; rm -rf "$S"
done
log "runner stop (STOP file)"
