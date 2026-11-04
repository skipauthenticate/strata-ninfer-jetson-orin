# Using the fast build

How to run IQ3_S with this branch's engine and the best settings found so far (round 3, `r3-e047`) on a Jetson AGX
Orin 64 GB. It assumes IQ3_S is already installed with setup at a 262,144-token context (`strata-iq3_s.json` exists).

1. Build the engine from this branch with setup's flags, in its own folder so the stock engine stays:

   ```bash
   cmake -G Ninja -S . -B build-fast -DCMAKE_BUILD_TYPE=Release -DSTRATA_ENABLE_CUDA=ON -DSTRATA_BUILD_TESTS=OFF \
     -DCMAKE_CUDA_ARCHITECTURES=87 -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.2/bin/nvcc \
     -DCUDAToolkit_ROOT=/usr/local/cuda-13.2 -DSTRATA_GGML_DIR=third_party/llama.cpp -DSTRATA_EXPERIMENTAL_SM60=ON
   cmake --build build-fast --target strata -j 4
   ```

2. Capture a warm expert profile once: start the stock server with
   `--expert-profile-save <profile.bin> --expert-profile-save-every 1` added to its arguments, send it a few
   requests like your real ones, and stop it. The overnight runs used three 4,096-token code-review prompts.

3. Build an 8-bit draft head from the draft layer's BF16 tensors that setup downloaded (`<Strata-data>/mtp`, the
   folder with `mtp-manifest.json`). It takes about a minute and writes 2.9 GB:

   ```bash
   mkdir -p <Strata-data>/mtp-hp
   PYTHONPATH=third_party/llama.cpp/gguf-py python3 tools/mtp_pack.py --src <Strata-data>/mtp --experts q8_0 \
     --out <Strata-data>/mtp-hp/mtp-q8_0.gguf
   ```

   Setup's draft layer runs its routed experts at 2 bits. The engine loads this file instead and requantizes the
   experts to IQ4_XS/IQ4_NL at load (`STRATA_MTP_EXPERTS_AS=iq4_xs`). Only the drafts change, and the main model
   verifies every draft, so the output text stays the same.

4. Write the fast configuration next to setup's one, and point the start script at it:

   ```bash
   python3 make_fast_config.py <strata folder> <path to build-fast/strata> <profile.bin> \
     <Strata-data>/mtp-hp/mtp-q8_0.gguf
   sed 's#strata-iq3_s.json#strata-iq3_s-fast.json#' run-iq3_s.sh > run-iq3_s-fast.sh
   ```

   The configuration adds `--expert-profile <profile.bin> --adapt-every 100000 --kv-grow --expert-cache 14629
   --mtp-hnorm stream`, round 1's twelve `STRATA_*` switches, and round 2's five: `STRATA_SPEC_CUM=0,0.40,0.47`,
   `STRATA_IO_PREFETCH=1`, `STRATA_MTP_EXPERTS=<mtp-q8_0.gguf>`, `STRATA_MTP_EXPERTS_AS=iq4_xs`,
   `STRATA_HC_DOWN_RR=1`, and round 3's four: `--pool-workers 7`, `STRATA_MISS_ZEROCOPY=1`, `STRATA_SPEC_COST=1`,
   `STRATA_SPEC_COST_TABLE=52.5,63.5,74.5,86.7`. Leave out the fourth argument to get round 1's settings without the
   draft head. The
   diagnostic switches the runs also set (`STRATA_DECODE_TIMING`, `STRATA_BW_PROBE`) are not included.

## Verified

Through the start script (`serve/server.py`), with the community `benchmark.py` (three fresh 4,096-token prompts,
256 greedy tokens), on the same Orin:

| | Decode tok/s, median [range] | Prompt tok/s | TTFT s | 32K needles |
| --- | ---: | ---: | ---: | --- |
| Round 3 settings, engine at commit `8f6ecdcd` (SHA-256 `69995077…`), 2026-11-04 | 36.98 [34.41–36.99] | 333.6 | 12.34 | 3/3 |
| Round 2 settings, engine at commit `8d466b5d` (SHA-256 `a6851e0a…`) | 34.89 [33.76–35.23] | 346.9 | 11.87 | 3/3 |
| Round 1 settings, engine SHA-256 `896d4c7a…` | 33.28 [32.39–34.87] | 301.3 | 13.65 | 3/3 |
| Stock engine, setup's default (2026-11-01 report) | 23.7 [21.3–26.7] | 234.7 | 17.5 | 3/3 |

With round 3's settings the same server session also ran round 3's prose and repetition workloads: 25.72 and 31.12
tok/s (round 2's settings: 18.4–18.6 and 16.4–16.6). The output text was identical to round 3's baselines on all
nine prompts, and the minimum free memory was 11.96 GiB (two idle services were stopped on the board; with them
running, round 2 measured 7.03). Files: [verify-r3-summary.json](verify-r3-summary.json),
[verify-r3-needles.json](verify-r3-needles.json).

With round 2's settings, the output text was identical to round 2's baselines on all three prompts, and the minimum
free memory was 7.03 GiB (round 1: 7.46). Files: [verify-r2-summary.json](verify-r2-summary.json),
[verify-r2-needles.json](verify-r2-needles.json); round 1's are [verify-summary.json](verify-summary.json) and
[verify-needles.json](verify-needles.json).

The caveats in the [main README](../README.md#caveats), [round 2's](../../2026-11-01-orin-decode-autoresearch-r2/README.md#caveats)
and [round 3's](../../2026-11-03-orin-decode-autoresearch-r3/README.md#caveats) apply: the bit-exact check has not been run, and the warm profile matches the workload it was captured on.
