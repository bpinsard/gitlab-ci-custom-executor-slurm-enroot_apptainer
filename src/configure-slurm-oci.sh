#!/usr/bin/env bash
# https://docs.gitlab.com/runner/executors/custom.html#config

# This script configures a slurm job
# using the slurm OCI support

set -o nounset
set -o errexit
set -o pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

########################
# WORKSPACE DEFINITION #
########################

# TODO: Test that this variables is set by the gitlab runner
# TODO: Change this to a job-id related name
WORKSPACE="$CUSTOM_ENV_CI_BUILDS_DIR"

##########
# MOUNTS #
##########
# shellcheck source=src/include.sh
source "$SRC"/include.sh

MIRROR_MOUNTS=(/scratch
               /etc/slurm/task_prolog.hk
               "$CUSTOM_ENV_CI_BUILDS_DIR")
MOUNTS_STRING="$(assemble_mounts "${MIRROR_MOUNTS[@]}")"



############################
# ENV VARIABLE TRANSLATION #
############################

for VAR in $("$SRC"/slurm-utils/get-sbatch-input-env-list.sh)
do
    export_custom_env_var_into_var_if_defined "$VAR"
done

###########################################################
# CHECK ON THE VALUE OF CUSTOM_ENV_COMMAND_OPTIONS_SBATCH #
###########################################################

set +o nounset
if [[ -z "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH" ]]
then
    echo "Warning: CUSTOM_ENV_COMMAND_OPTIONS_SBATCH not set, working with default options" >&2
    CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=cpu_only -n 1 -t 30"
else
    check_custom_env_command_options_sbatch_for_forbidden_options --container-image --container-mounts
fi
set -o nounset


###########################
# FINAL SBATCH INVOCATION #
###########################

sbatch "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH" \
       --container-image="$CUSTOM_ENV_CI_JOB_IMAGE" \
       --container-mounts="$MOUNTS_STRING" \
       "$SRC"/job.slurm "$WORKSPACE"


cat <<EOF
{"job_env":{}}
EOF
