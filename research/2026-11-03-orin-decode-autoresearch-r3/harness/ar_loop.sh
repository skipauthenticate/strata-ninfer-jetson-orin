#!/bin/bash
# Karpathy-style loop: a fresh headless agent per iteration reads program.md and the files, runs experiments, exits.
# Tools are allowlisted (dontAsk; Edit rules also cover Write): edits only in the source tree / notes / overrides; shell only for the harness,
# read-only tools and local git (no push). Stops at the deadline (hours, default 8), on STOP or TARGET_MET, after
# 4 failed iterations in a row (each failure waits 25 minutes, e.g. a usage limit), or after 10 iterations in a row
# without a new results row.
cd "$(dirname "$0")"
HOURS=${1:-8}; END=$(( $(date +%s) + HOURS * 3600 )); i=0; fails=0; idle=0
A=~/workspace/strata-ar; LAB=~/workspace/strata-ar-lab-r3
ALLOW=(Read Glob Grep
  "Edit(/$A/src/**)" "Edit(/$A/include/**)" "Edit(/$A/cmake/**)" "Edit(/$A/CMakeLists.txt)"
  "Edit(/$LAB/overrides/**)" "Edit(/$LAB/notes.md)" "Edit(/$LAB/TARGET_MET)" "Edit(/$LAB/research-ideas.md)"
  "Bash(./ar_run.sh:*)" "Bash(./ar_queue.sh:*)" "Bash(./ar_collect.sh:*)" "Bash(./ar_probe.sh:*)" "Bash(python3 compare.py:*)"
  "Bash(git -C $A status:*)" "Bash(git -C $A diff:*)" "Bash(git -C $A log:*)" "Bash(git -C $A add:*)"
  "Bash(git -C $A commit:*)" "Bash(git -C $A checkout -- :*)" "Bash(git -C $A show:*)" "Bash(git -C $A stash:*)"
  "Bash(cat:*)" "Bash(ls:*)" "Bash(head:*)" "Bash(tail:*)" "Bash(grep:*)" "Bash(wc:*)" "Bash(diff:*)" "Bash(sort:*)"
  "Bash(column:*)" "Bash(cut:*)" "Bash(date:*)"
  "Bash(gh api repos/calvinvette/strata-ninfer-jetson-orin/contents/:*)")
DENY=("Bash(git -C $A push:*)" "Bash(git push:*)" WebFetch WebSearch)
while [ "$(date +%s)" -lt $END ] && [ ! -e STOP ] && [ ! -e TARGET_MET ]; do
  i=$((i + 1)); log=logs/iter-$(printf %03d $i).log; rows=$(wc -l < results.tsv)
  echo "$(date +%FT%T) iteration $i" >> logs/loop.log
  timeout 5400 claude -p "$(cat program.md)" --model opus --permission-mode dontAsk \
    --allowedTools "${ALLOW[@]}" --disallowedTools "${DENY[@]}" --max-turns 250 --output-format text > "$log" 2>&1
  rc=$?; grep -q "Reached max turns" "$log" && rc=0   # a long iteration that saved its notes is not a failure
  echo "$(date +%FT%T) iteration $i exit $rc, results rows $rows -> $(wc -l < results.tsv)" >> logs/loop.log
  if [ $rc -ne 0 ]; then fails=$((fails + 1)); [ $fails -ge 4 ] && { echo "$(date +%FT%T) stopping: 4 failed iterations" >> logs/loop.log; break; }; sleep 1500; else fails=0; fi
  if [ "$(wc -l < results.tsv)" -eq "$rows" ]; then idle=$((idle + 1)); else idle=0; fi
  [ $idle -ge 10 ] && { echo "$(date +%FT%T) stopping: 10 iterations without a new result" >> logs/loop.log; break; }
done
echo "$(date +%FT%T) loop end" >> logs/loop.log
