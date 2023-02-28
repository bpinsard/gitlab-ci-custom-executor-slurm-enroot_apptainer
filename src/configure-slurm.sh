#!/usr/bin/env bash
# https://docs.gitlab.com/runner/executors/custom.html#config

# This script configures a slurm job
# using the slurm OCI support

if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
set -o nounset
set -o errexit
set -o pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=src/config-include.sh
source "$SRC"/config-include.sh

check_custom_env_ci_ws_set
WORKSPACE="$CUSTOM_ENV_CI_WS"/cews_"$CUSTOM_ENV_CI_JOB_ID"

export_all_custom_env_var_into_var_if_defined

check_or_set_custom_env_command_sbatch

JOB_ID=$(eval "$(get_sbatch_command
                 "$WORKSPACE"
                 "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH")")

while ! scontrol wait_job "$JOB_ID"
do
    sleep 3
done
wait_until_file_exists "$WORKSPACE/.env" 90

 
cat <<EOF
{
  "driver": {
    "name": "Slurm driver+enroot/singularity",
    "version": "v0.0.1"
  },
"job_env": {
    "CE_SLURM_JOB_ID": "$JOB_ID",
    "CE_QUEUE_ENV_PATH" : "$WORKSPACE/.env"
  }
}
EOF


