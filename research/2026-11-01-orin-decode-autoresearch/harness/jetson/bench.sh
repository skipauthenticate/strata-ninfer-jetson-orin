#!/bin/bash
# One autoresearch measurement: the IQ3_S 256K server with overrides; 3 fresh 4,096-token prompts x 256 tokens;
# optional 32K needles. Holds ~/gpu.lock (not inherited by the server); run_control.py enforces the 6 GiB
# MemAvailable floor; a trap stops the server on any exit. Lock wait <= 1 h; after it every step has its own timeout.
# usage: bench.sh EXP_ID EXE OVERRIDES.json [needles]      (~/strata/ar/base-overrides.json is applied first)
set -u
EXP=$1; EXE=$2; OVR=$3; NEEDLES=${4:-}
R=/home/<user>/strata/strata-ninfer-jetson-orin
A=/home/<user>/strata/ar; O=$A/runs/$EXP
PAT="serve/server.py --engine strata --config $O/config.json"
rm -rf "$O"; mkdir -p "$O"
sha256sum "$EXE" | cut -c1-16 > "$O/exe.sha256"
python3 $A/make_config.py $R/strata-iq3_s.json "$EXE" "$O/config.json" $A/base-overrides.json "$OVR" > "$O/args.txt" 2>&1 \
  || { echo "{\"status\": \"bad_overrides\", \"error\": $(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read()))' "$O/args.txt")}" > "$O/result.json"; cat "$O/result.json"; exit 1; }
sup=""
cleanup() {
  [ -n "$sup" ] && { pkill -INT -f "$PAT"; for i in $(seq 1 30); do kill -0 $sup 2>/dev/null || break; sleep 1; done; pkill -KILL -f "$PAT"; }
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP
exec 9>"$HOME/gpu.lock"
flock -w 3600 9 || { echo '{"status": "lock_timeout"}' > "$O/result.json"; cat "$O/result.json"; exit 1; }
date -Is > "$O/started.txt"
cd $R
python3 tools/integration/run_control.py --output "$O/supervisor" --timeout 1080 --interval 2 -- \
  .venv/bin/python serve/server.py --engine strata --config "$O/config.json" --port 18090 > "$O/server.txt" 2>&1 9>&- &
sup=$!
ready=0
for i in $(seq 1 300); do
  curl -sf -m 5 http://127.0.0.1:18090/health 2>/dev/null | grep -q '"loaded": true' && { ready=1; break; }
  kill -0 $sup 2>/dev/null || break; sleep 2
done
if [ $ready = 1 ]; then
  timeout 600 .venv/bin/python $A/benchmark.py --root $R --pack /home/<user>/strata/Strata-data/packs/iq3_s \
    --url http://127.0.0.1:18090 --out "$O/speed" --targets 4096 --runs 3 > "$O/benchmark.txt" 2>&1 9>&-
  if [ -n "$NEEDLES" ]; then
    timeout 600 .venv/bin/python tools/needle_bench.py --url http://127.0.0.1:18090 --lengths 32k --depths 10,50,90 \
      --out "$O/needles.json" > "$O/needles.txt" 2>&1 9>&-
  fi
fi
cleanup; sup=""
wait 2>/dev/null
python3 $A/summarize_run.py "$O" > "$O/result.json"
cat "$O/result.json"
