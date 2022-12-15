#!/usr/bin/env bash
# https://docs.gitlab.com/runner/executors/custom.html#config

# This script configures a slurm job
# using the slurm OCI support

if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
set -o nounset
set -o errexit
set -o pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

########################
# WORKSPACE DEFINITION #
########################

# TODO: Test that this variables is set by the gitlab runner
# TODO: Change this to a job-id related name
WORKSPACE="$CUSTOM_ENV_CI_BUILDS_DIR"/cews

##########
# MOUNTS #
##########
# shellcheck source=src/include.sh
source "$SRC"/include.sh
# shellcheck source=src/config-include.sh
source "$SRC"/config-include.sh

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
    CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -n 1 -t 30"
fi
set -o nounset


########################
# COMMAND CONSTRUCTION #
########################
# Forming the command step by step
# Here we do want the variable to be split
# shellcheck disable=SC2206
COMMAND=(sbatch $CUSTOM_ENV_COMMAND_OPTIONS_SBATCH
         --propagate=NONE
         --parsable
	 --signal=B:USR1@15 # SIGUSR1 15 seconds before the end of the job.
	 )

#################
# DEBUG OPTIONS #
#################

set +o nounset
if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
then
    COMMAND+=( --input=/dev/null
               --output=/dev/null
               --error=/dev/null
	      )
fi
set -o nounset


###########################
# FINAL SBATCH INVOCATION #
###########################
COMMAND+=("$SRC"/job.slurm "$WORKSPACE" "$SRC")

echo "${COMMAND[@]}" >&2
JOB_ID=$("${COMMAND[@]}")

cat <<EOF
{
  "driver": {
    "name": "ENROOT+Slurm driver",
    "version": "v0.0.1"
  },
"job_env": {
    "CE_SLURM_JOB_ID": "$JOB_ID",
    "CE_QUEUE_ENV_PATH" : "$WORKSPACE/.env"
  }
}
EOF
