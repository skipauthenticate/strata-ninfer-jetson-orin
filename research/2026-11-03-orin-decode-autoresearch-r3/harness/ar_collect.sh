#!/bin/bash
# Log every queued experiment that has finished on the Jetson (results.tsv rows, gates), then show the queue.
# usage: ./ar_collect.sh
set -u
cd "$(dirname "$0")"
# one collect at a time (orchestrator, 16:30 PST): two at once both logged r3-e095, a duplicate results row
[ -z "${AR_COLLECT_LOCKED:-}" ] && AR_COLLECT_LOCKED=1 exec lockf -k -t 900 logs/.collect.lock "$0" "$@"
J=jetson; SRC=$HOME/workspace/strata-ar
. ./jrun.sh
collect_orphans
ssh "$J" 'Q=~/strata/ar/queue; echo "running: $(ls $Q/running 2>/dev/null | sed -E "s/^[0-9]+-[0-9]+-//; s/.job$//" | tr "\n" " ")"; echo "pending: $(ls $Q/pending 2>/dev/null | grep -c .job)  $(ls $Q/pending 2>/dev/null | sed -E "s/^[0-9]+-[0-9]+-//; s/.job$//" | tr "\n" " ")"; flock -n $Q/runner.lock true && echo "runner: not running (./ar_queue.sh starts it)" || echo "runner: active"'
