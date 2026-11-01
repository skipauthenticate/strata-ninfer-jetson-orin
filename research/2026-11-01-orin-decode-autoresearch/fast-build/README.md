# Using the fast build

How to run IQ3_S with this branch's engine and the overnight best settings on a Jetson AGX Orin 64 GB. It assumes
IQ3_S is already installed with setup at a 262,144-token context (`strata-iq3_s.json` exists).

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

3. Write the fast configuration next to setup's one, and point the start script at it:

   ```bash
   python3 make_fast_config.py <strata folder> <path to build-fast/strata> <profile.bin>
   sed 's#strata-iq3_s.json#strata-iq3_s-fast.json#' run-iq3_s.sh > run-iq3_s-fast.sh
   ```

   The configuration adds `--expert-profile <profile.bin> --adapt-every 100000 --kv-grow --expert-cache 14629
   --mtp-hnorm stream` and the twelve `STRATA_*` switches listed in the script. It leaves out the two diagnostic
   switches the overnight runs also set (`STRATA_DECODE_TIMING`, `STRATA_BW_PROBE`).

## Verified

Through `serve/server.py`, with the community `benchmark.py` (three fresh 4,096-token prompts, 256 greedy tokens), on
the same Orin after the rebuild (engine SHA-256 `896d4c7a…`):

| | Decode tok/s | Prompt tok/s | TTFT s |
| --- | ---: | ---: | ---: |
| Fast build, median [range] | 33.28 [32.39–34.87] | 301.3 | 13.65 |
| Stock engine, setup's default (2026-11-01 report) | 23.7 [21.3–26.7] | 234.7 | 17.5 |

The 32K needle check found 3 of 3 ([verify-needles.json](verify-needles.json)); the minimum free memory was 7.46 GiB.
The caveats in the [main README](../README.md#caveats) apply: the bit-exact check has not been run, and the warm
profile matches the workload it was captured on.
