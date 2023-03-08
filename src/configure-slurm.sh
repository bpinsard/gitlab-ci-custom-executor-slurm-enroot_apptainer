#!/usr/bin/env bash
# https://docs.gitlab.com/runner/executors/custom.html#config

# This script configures a slurm job
# using the slurm OCI support

if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
set -o nounset
set -o errexit
set -o pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=src/configure-slurm-include.sh
source "$SRC"/configure-slurm-include.sh

check_custom_env_ci_ws_set


export_all_custom_env_var_into_var_if_defined

check_or_set_custom_env_command_sbatch

check_string_has_no_forbidden_options "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH" || {
  echo "Error: forbidden option in COMMAND_OPTIONS_SBATCH.">&2
  exit "$SYSTEM_FAILURE_EXIT_CODE"
}


SLURMENV_CANDIDATE="$CUSTOM_ENV_CI_WS/slurmenv_candidate_$CUSTOM_ENV_CI_JOB_ID"

save_slurm_environment > "$SLURMENV_CANDIDATE"

WORKSPACE="$(find_available_workspace_name "$CUSTOM_ENV_CI_WS"/cews_)"


JOB_ID=$(eval "$(get_sbatch_command \
                 "$WORKSPACE" \
                 "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH")")


wait_for_job_to_be_ready "$JOB_ID"
wait_until_file_exists "$WORKSPACE/.env" 90

mv "$SLURMENV_CANDIDATE" "$WORKSPACE/slurmenv"
 
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
