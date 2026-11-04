#!/bin/bash
# Engine-level probe (generate mode, not the server): base config + overrides + extra engine args on the fixed
# 4,096-token prompt. For --stats, --gpu-only-full, --spec-follow/--window-hashes, --dump-* experiments.
# usage: probe.sh EXP_ID EXE OVERRIDES.json "extra engine args"
set -u
EXP=$1; EXE=$2; OVR=$3; EXTRA=$4
R=/home/<user>/strata/strata-ninfer-jetson-orin; A=/home/<user>/strata/ar; O=$A/runs/$EXP
rm -rf "$O"; mkdir -p "$O"
[ -s $A/prompt-4096.tokens ] || .venv/bin/python $A/gen_tokens.py 4096 > $A/prompt-4096.tokens
python3 $A/make_config.py $R/strata-iq3_s.json "$EXE" "$O/config.json" $A/base-overrides.json "$OVR" > "$O/args.txt" 2>&1 || { cat "$O/args.txt"; exit 1; }
ARGS=$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["args"]))' "$O/config.json")
# the fixed 4,096-token prompt unless the probe brings its own (the engine takes one token input only)
TOK="--tokens-file $A/prompt-4096.tokens"; case "$EXTRA" in *--tokens-file*) TOK="";; esac
exec 9>"$HOME/gpu.lock"
flock -w 3600 9 || { echo "lock_timeout"; exit 1; }
cd $R
export LD_LIBRARY_PATH=/usr/local/cuda-13.2/lib64:${LD_LIBRARY_PATH:-}
eval "$(python3 -c 'import json,shlex,sys; [print("export %s=%s" % (k, shlex.quote(v))) for k, v in json.load(open(sys.argv[1]))["env"].items()]' "$O/config.json")"
eval "python3 tools/integration/run_control.py --output '$O/supervisor' --timeout 1080 --interval 2 -- \
  '$EXE' $ARGS $TOK $EXTRA" > "$O/probe.txt" 2>&1 9>&-
rc=$?
# run_control keeps the engine's own output in supervisor/; put it in probe.txt after the supervisor summary
{ echo "=== engine stdout"; cat "$O/supervisor/stdout.txt" 2>/dev/null; echo "=== engine stderr"; cat "$O/supervisor/stderr.txt" 2>/dev/null; } >> "$O/probe.txt"
echo "exit $rc ; output: $O/probe.txt"
tail -60 "$O/probe.txt"
