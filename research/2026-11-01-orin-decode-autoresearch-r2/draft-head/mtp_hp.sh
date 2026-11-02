#!/bin/bash
# Build 4-bit and 8-bit MTP draft-head GGUFs from the BF16 checkpoint tensors, holding the shared GPU lock so no
# benchmark runs while numpy reads 5 GB. Output: ~/strata/Strata-data/mtp-hp/mtp-{q4_0,q8_0}.gguf
set -u
OUT=$HOME/strata/Strata-data/mtp-hp
mkdir -p "$OUT"
exec 9>"$HOME/gpu.lock"
echo "$(date -Is) waiting for the lock"
flock -w 7200 9 || { echo "lock_timeout"; exit 1; }
echo "$(date -Is) lock held"
cd $HOME/strata/ar/src
for q in q4_0 q8_0; do
  PYTHONPATH=third_party/llama.cpp/gguf-py nice -n 5 python3 tools/mtp_pack.py --src $HOME/strata/Strata-data/mtp \
    --experts $q --out "$OUT/mtp-$q.gguf" || { echo "pack $q failed"; exit 1; }
  sha256sum "$OUT/mtp-$q.gguf"
done
echo "$(date -Is) done"
