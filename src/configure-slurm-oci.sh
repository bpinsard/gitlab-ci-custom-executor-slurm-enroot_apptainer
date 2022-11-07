#!/usr/bin/env bash
# https://docs.gitlab.com/runner/executors/custom.html#config

# This script configures a slurm job
# using the slurm OCI support


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"


##########
# MOUNTS #
##########
# shellcheck source=src/include.sh
source "$SRC"/include.sh

MIRROR_MOUNTS=(/scratch
               /etc/slurm/task_prolog.hk)
MOUNTS_STRING="$(assemble_mounts "${MIRROR_MOUNTS[@]}")"


########################
# WORKSPACE DEFINITION #
########################

# TODO: Test that this variables is set by the gitlab runner
# TODO: Change this to a job-id related name
WORKSPACE="$CUSTOM_ENV_CI_BUILDS_DIR"


############################
# ENV VARIABLE TRANSLATION #
############################


for VAR in $("$SRC"/slurm-utils/get-sbatch-input-env-list.sh)
do
done


###########################
# FINAL SBATCH INVOCATION #
###########################


sbatch --container-image="$CUSTOM_ENV_CI_JOB_IMAGE" \
       --container-mounts="$MOUNTS_STRING" \
       "$SRC"/job.slurm 5 2 "$WORKSPACE"
