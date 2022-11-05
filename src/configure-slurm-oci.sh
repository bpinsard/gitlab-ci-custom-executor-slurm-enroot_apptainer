#!/usr/bin/env bash
# https://docs.gitlab.com/runner/executors/custom.html#config

# This script configures a slurm job
# using the slurm OCI support



touch mock.sh
chmod +x mock.sh

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

MIRROR_MOUNTS=(/scratch
               /etc/slurm/task_prolog.hk)

# shellcheck source=src/include.sh
source "$DIR"/include.sh



sbatch --container-image="$CUSTOM_ENV_CI_JOB_IMAGE" \
       --container-mounts="$(assemble_mounts "${MIRROR_MOUNTS[@]}")" \
    mock.sh
