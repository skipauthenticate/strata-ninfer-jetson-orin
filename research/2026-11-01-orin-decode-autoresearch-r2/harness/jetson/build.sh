#!/bin/bash
# Incremental engine build of the autoresearch tree (~/strata/ar/src -> ~/strata/ar/build/strata), the same flags
# setup used for the installed engine. Waits while a timed GPU run holds the lock only for the configure step.
set -o pipefail
A=/home/<user>/strata/ar; S=$A/src; B=$A/build
if [ ! -f $B/build.ninja ]; then
  cmake -G Ninja -S $S -B $B -DCMAKE_BUILD_TYPE=Release -DSTRATA_ENABLE_CUDA=ON -DSTRATA_BUILD_TESTS=OFF \
    -DCMAKE_CUDA_ARCHITECTURES=87 -DCMAKE_CUDA_COMPILER=/usr/local/cuda-13.2/bin/nvcc -DCUDAToolkit_ROOT=/usr/local/cuda-13.2 \
    -DSTRATA_GGML_DIR=$S/third_party/llama.cpp -DSTRATA_EXPERIMENTAL_SM60=ON > $A/cmake.log 2>&1 || { tail -40 $A/cmake.log; exit 1; }
fi
nice -n 10 ninja -C $B -j 4 strata 2>&1 | grep -vE "warning #|^\s*\^|Remark|^$|^ +[0-9]+ \||declared but never referenced" | tail -40
exit ${PIPESTATUS[0]}
