# Shared by ar_run.sh, ar_queue.sh, ar_probe.sh, ar_collect.sh (sourced; needs J, SRC). Every Jetson build and
# measurement goes through the Jetson's queue runner (jetson/qrunner.sh): the Mac only uploads a source snapshot and a
# job, so a Mac that sleeps or loses the connection only delays reading results.

# jqueue PRIO KIND EXP OVR_FILE NEEDLES EXTRA: upload the source snapshot and the overrides, write the job, make sure
# the runner is up. PRIO 0 = a waiting ar_run/ar_probe (runs before queued work), 1 = queued.
jqueue() {
  local prio=$1 kind=$2 e=$3 ovr=$4 needles=$5 extra=$6 i n
  for i in 1 2 3; do
    ssh -o ConnectTimeout=20 "$J" "mkdir -p ~/strata/ar/jobsrc/$e ~/strata/ar/queue/pending" \
      && rsync -a --delete "$SRC/src/" "$J:strata/ar/jobsrc/$e/src/" && rsync -a --delete "$SRC/include/" "$J:strata/ar/jobsrc/$e/include/" \
      && rsync -a --delete "$SRC/cmake/" "$J:strata/ar/jobsrc/$e/cmake/" && rsync -a "$SRC/CMakeLists.txt" "$J:strata/ar/jobsrc/$e/CMakeLists.txt" \
      && scp -q "$ovr" "$J:strata/ar/overrides-$e.json" && break
    [ $i = 3 ] && return 3; sleep 30
  done
  n=$prio-$(date +%Y%m%d%H%M%S)-$e
  printf 'EXP=%s\nKIND=%s\nOVR=/home/<user>/strata/ar/overrides-%s.json\nNEEDLES=%s\nEXTRA64=%s\n' \
    "$e" "$kind" "$e" "$needles" "$(printf '%s' "$extra" | base64 | tr -d '\n')" \
    | ssh "$J" "cat > ~/strata/ar/queue/pending/$n.job.tmp && mv ~/strata/ar/queue/pending/$n.job.tmp ~/strata/ar/queue/pending/$n.job" || return 3
  # start the runner if none is active (a second one exits at once on runner.lock)
  ssh "$J" 'nohup setsid bash ~/strata/ar/qrunner.sh > /dev/null 2>&1 < /dev/null &'
}

# jwait KIND EXP: wait (through Mac sleep and dropped connections, at most 6 h) for a job's exit code, then print its
# stdout (stderr to ours) and return its exit code
jwait() {
  local t0; t0=$(date +%s)
  until ssh -o ConnectTimeout=20 "$J" "test -e ~/strata/ar/detached/$1-$2.rc" 2> /dev/null; do
    [ $(( $(date +%s) - t0 )) -gt 21600 ] && { echo "jwait $1 $2: no exit code after 6 h" >&2; return 254; }
    sleep 15
  done
  jfetch "$1-$2"
}

# jfetch NAME: print a finished detached command's stdout (stderr to ours) and return its exit code
jfetch() {
  local i rc
  for i in 1 2 3 4 5 6; do
    rc=$(ssh -o ConnectTimeout=20 "$J" "cat ~/strata/ar/detached/$1.rc" 2> /dev/null) && break; sleep 20
  done
  ssh "$J" "cat ~/strata/ar/detached/$1.out"; ssh "$J" "cat ~/strata/ar/detached/$1.err" >&2
  return "${rc:-255}"
}

# finish EXP: copy the run's logs back, gate it against the round 3 baselines, append its results.tsv row
finish() {
  local e=$1 desc commit bases gate
  desc=$(sed -n 1p "runs/$e/meta.txt"); commit=$(sed -n 2p "runs/$e/meta.txt")
  scp -q "$J:strata/ar/detached/build-$e.log" "runs/$e/build.log" 2> /dev/null
  grep -q '"build_fail"' "runs/$e/result.json" 2> /dev/null && { echo "BUILD FAILED (runs/$e/build.log):"; tail -30 "runs/$e/build.log"; }
  scp -q "$J:strata/ar/runs/$e/engine.log" "runs/$e/engine.log" 2> /dev/null
  scp -q "$J:strata/ar/runs/$e/args.txt" "runs/$e/args.txt" 2> /dev/null
  bases=$(sed -n 's#^\(r3-[A-Za-z0-9._-]*\)$#runs/\1/result.json#p' gate-baselines.txt 2> /dev/null | grep -v "runs/$e/")
  gate=$(python3 compare.py "runs/$e/result.json" $bases 2> /dev/null || echo '{}')
  echo "$gate" > "runs/$e/gate.json"
  python3 - "$e" "$desc" "$commit" "runs/$e/result.json" "runs/$e/gate.json" <<'PY' | tee -a results.tsv
import json, sys, datetime
exp, desc, commit, rp, gp = sys.argv[1:6]
try: r = json.load(open(rp))
except Exception: r = {"status": "no_result_json"}
g = json.load(open(gp)) if open(gp).read().strip() else {}
status = r.get("status")
if status == "ok" and g.get("slots_match") is False:
    status = "ok_slots_drift"   # cache size differs from the baselines: re-run before judging the text
cols = [exp, datetime.datetime.now().isoformat(timespec="seconds"), desc, commit, status,
        r.get("decode_med"), r.get("decode_min"), r.get("decode_max"), r.get("prefill_med"), r.get("ttft_med"),
        r.get("min_avail_gib"), r.get("hit_rate_last"), r.get("cache_slots"), g.get("agreement_min"), r.get("needles", ""),
        r.get("exe_sha256"), "; ".join(r.get("engine_errors") or [])[:200],
        r.get("prose_med"), r.get("rep_med"), r.get("pr_mean")]
print("\t".join("" if c is None else str(c) for c in cols))
PY
  touch "runs/$e/done"
  python3 -c "import json,sys; r=json.load(open(sys.argv[1])); r.pop('texts',None); print(json.dumps(r)[:900])" "runs/$e/result.json" 2> /dev/null
  echo "gate: $gate"
}

# collect_orphans: measurements that finished on the Jetson after their ar_run.sh died (Mac asleep, iteration timeout)
collect_orphans() {
  local m e
  for m in runs/r3-*/meta.txt; do
    [ -e "$m" ] || continue
    e=$(basename "$(dirname "$m")")
    [ -e "runs/$e/done" ] && continue
    ssh -o ConnectTimeout=20 "$J" "test -e ~/strata/ar/detached/bench-$e.rc" 2> /dev/null || continue
    echo "collecting $e: it finished on the Jetson after its ar_run.sh ended"
    jfetch "bench-$e" > "runs/$e/result.json" 2> "runs/$e/bench.stderr"
    finish "$e"
  done
}
