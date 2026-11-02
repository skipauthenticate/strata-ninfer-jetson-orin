# Shared by ar_run.sh and ar_probe.sh (sourced; needs J). The Jetson steps run detached (jetson/detach.sh), so the
# Mac sleeping or losing the connection only delays a result: the wait resumes on wake, and a measurement whose
# ar_run.sh died is collected by the next ar_run.sh (collect_orphans).

# jrun NAME CMD [ARGS...]: run CMD on the Jetson detached; wait for it; its stdout/stderr to ours; return its exit code
jrun() {
  local n=$1 t0 rc; shift
  ssh -o ConnectTimeout=20 "$J" "bash ~/strata/ar/detach.sh $(printf '%q ' "$n" "$@")" > /dev/null || return 255
  t0=$(date +%s)
  until ssh -o ConnectTimeout=20 "$J" "test -e ~/strata/ar/detached/$n.rc" 2> /dev/null; do
    [ $(( $(date +%s) - t0 )) -gt 14400 ] && { echo "jrun $n: no exit code after 4 h" >&2; return 254; }
    sleep 15
  done
  jfetch "$n"
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

# finish EXP: copy the run's logs back, gate it against the round 2 baselines, append its results.tsv row
finish() {
  local e=$1 desc commit bases gate
  desc=$(sed -n 1p "runs/$e/meta.txt"); commit=$(sed -n 2p "runs/$e/meta.txt")
  scp -q "$J:strata/ar/runs/$e/engine.log" "runs/$e/engine.log" 2> /dev/null
  scp -q "$J:strata/ar/runs/$e/args.txt" "runs/$e/args.txt" 2> /dev/null
  bases=$(ls runs/r2-baseline-*/result.json 2> /dev/null | grep -v "runs/$e/")
  gate=$(python3 compare.py "runs/$e/result.json" $bases 2> /dev/null || echo '{}')
  echo "$gate" > "runs/$e/gate.json"
  python3 - "$e" "$desc" "$commit" "runs/$e/result.json" "runs/$e/gate.json" <<'PY' | tee -a results.tsv
import json, sys, datetime
exp, desc, commit, rp, gp = sys.argv[1:6]
try: r = json.load(open(rp))
except Exception: r = {"status": "no_result_json"}
g = json.load(open(gp)) if open(gp).read().strip() else {}
cols = [exp, datetime.datetime.now().isoformat(timespec="seconds"), desc, commit, r.get("status"),
        r.get("decode_med"), r.get("decode_min"), r.get("decode_max"), r.get("prefill_med"), r.get("ttft_med"),
        r.get("min_avail_gib"), r.get("hit_rate_last"), r.get("cache_slots"), g.get("agreement_min"), r.get("needles", ""),
        r.get("exe_sha256"), "; ".join(r.get("engine_errors") or [])[:200]]
print("\t".join("" if c is None else str(c) for c in cols))
PY
  touch "runs/$e/done"
  python3 -c "import json,sys; r=json.load(open(sys.argv[1])); r.pop('texts',None); print(json.dumps(r)[:900])" "runs/$e/result.json" 2> /dev/null
  echo "gate: $gate"
}

# collect_orphans: measurements that finished on the Jetson after their ar_run.sh died (Mac asleep, iteration timeout)
collect_orphans() {
  local m e
  for m in runs/r2-*/meta.txt; do
    [ -e "$m" ] || continue
    e=$(basename "$(dirname "$m")")
    [ -e "runs/$e/done" ] && continue
    ssh -o ConnectTimeout=20 "$J" "test -e ~/strata/ar/detached/bench-$e.rc" 2> /dev/null || continue
    echo "collecting $e: it finished on the Jetson after its ar_run.sh ended"
    jfetch "bench-$e" > "runs/$e/result.json" 2> "runs/$e/bench.stderr"
    finish "$e"
  done
}

# sync the source tree to the Jetson (three tries: the connection may be down for a moment)
jsync() {
  local i
  for i in 1 2 3; do
    rsync -a --delete "$SRC/src/" "$J:strata/ar/src/src/" && rsync -a --delete "$SRC/include/" "$J:strata/ar/src/include/" \
      && rsync -a --delete "$SRC/cmake/" "$J:strata/ar/src/cmake/" && rsync -a "$SRC/CMakeLists.txt" "$J:strata/ar/src/CMakeLists.txt" \
      && return 0
    sleep 30
  done
  return 1
}
