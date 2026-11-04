#!/bin/bash
# Run a command on the Jetson detached from the ssh session, so a Mac that sleeps or drops the connection does not
# stop it. Output: ~/strata/ar/detached/NAME.out and NAME.err; NAME.rc (the exit code) appears when it ends.
# usage: detach.sh NAME CMD [ARGS...]
set -u
N=$1; shift
D=$HOME/strata/ar/detached; mkdir -p "$D"
case "$N" in *[!A-Za-z0-9._-]*|"") echo "bad name: $N" >&2; exit 2;; esac
[ -e "$D/$N.out" ] && { echo "$N was started before" >&2; exit 2; }
: > "$D/$N.out"
nohup setsid bash -c '"$@" > "$0.out" 2> "$0.err" < /dev/null; echo $? > "$0.rc.tmp"; mv "$0.rc.tmp" "$0.rc"' \
  "$D/$N" "$@" > /dev/null 2>&1 < /dev/null &
echo "started $N"
