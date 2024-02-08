#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}" )/../.." > /dev/null 2>&1 && pwd)"

# To make scripts in /src available for sourcing
# and loading, and also make the sbatch mock available.
export SRC="$PROJECT_ROOT"/src
export PATH="$PROJECT_ROOT"/tests/mocks/bin:$PATH

mkdir -p playground


export CUSTOM_ENV_CI_JOB_IMAGE="ubuntu:kinetic-20221101"
export CUSTOM_ENV_CI_JOB_ID="12345"
export CUSTOM_ENV_CI_WS=$PWD/playground
export CUSTOM_ENV_DEFAULT_PARTITION='develop'
export CUSTOM_ENV_CI_CONCURRENT_ID='1'
export MOCKLOGDIR=$PWD/playground



"$SRC"/configure.sh none useslurm
