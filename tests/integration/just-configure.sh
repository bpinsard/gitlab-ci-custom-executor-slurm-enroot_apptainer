#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

# To make scripts in /src available for sourcing
# and loading, and also make the sbatch mock available.
export SRC="$PROJECT_ROOT"/src

mkdir -p playground


export CUSTOM_ENV_CE_DEBUG=1
export CUSTOM_ENV_CI_JOB_IMAGE="ubuntu:kinetic-20221101"
export CUSTOM_ENV_CI_BUILDS_DIR=$PWD/playground



"$SRC"/configure-slurm.sh
