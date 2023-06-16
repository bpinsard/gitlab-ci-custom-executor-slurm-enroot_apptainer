#!/usr/bin/env bash
# https://docs.gitlab.com/runner/executors/custom.html#config

# This script configures a slurm job
# using the slurm OCI support

if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
if [ -z "$CUSTOM_ENV_JOB_TIME_SEC" ]
then
  CUSTOM_ENV_JOB_TIME_SEC=600
fi
set -o nounset
set -o errexit
set -o pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=src/configure-slurm-include.sh
source "$SRC"/configure-slurm-include.sh

check_custom_env_ci_ws_set

export_all_custom_env_var_into_var_if_defined




SLURMENV_CANDIDATE="$CUSTOM_ENV_CI_WS/slurmenv_candidate_$CUSTOM_ENV_CI_JOB_ID"
print_slurm_environment > "$SLURMENV_CANDIDATE"


WORKSPACE=""
shopt -s nullglob
for DIR in "$CUSTOM_ENV_CI_WS"/cews_*
do
  echo "[CONFIGURE] Testing $SLURMENV_CANDIDATE $CUSTOM_ENV_JOB_TIME_SEC $DIR" >&2

  if allocation_is_compatible "$SLURMENV_CANDIDATE" "$CUSTOM_ENV_JOB_TIME_SEC" "$DIR"
  then
    WORKSPACE="$DIR"
    echo "[CONFIGURE] Found suitable workspace in $WORKSPACE" >&2
    echo "[CONFIGURE] Slurm job: $(get_slurm_jobid "$WORKSPACE")" >&2
  fi
done

if [ -z "$WORKSPACE" ]
then
    echo "[CONFIGURE] No suitable workspace found." >&2

    # finding a new workspace
    WORKSPACE="$(find_available_workspace_name "$CUSTOM_ENV_CI_WS"/cews_)"
    echo "[CONFIGURE] Creating workspace $WORKSPACE ..." >&2

    JOBSLURM="$(create_job_slurm "$SRC/job.slurm.template" \
                                 "$CUSTOM_ENV_DEFAULT_PARTITION" \
                                 "$WORKSPACE")"

    echo "[CONFIGURE] Creating job script at $JOBSLURM ..." >&2

    check_or_set_custom_env_command_sbatch "$JOBSLURM"

    check_string_has_no_forbidden_options "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH" || {
      echo "[CONFIGURE] Error: forbidden option in COMMAND_OPTIONS_SBATCH.">&2
      exit "$SYSTEM_FAILURE_EXIT_CODE"
    }

    JOB_ID=$(eval "$(get_sbatch_command \
                     "$WORKSPACE" \
                     "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH" \
                     "$JOBSLURM")")

    echo "[CONFIGURE] Submitted job $JOB_ID ..." >&2
    wait_for_job_to_be_ready "$JOB_ID"
    wait_until_file_exists "$WORKSPACE/.env" 90

    mv "$SLURMENV_CANDIDATE" "$WORKSPACE/slurmenv"
    echo "[CONFIGURE] Configured workspace in $WORKSPACE" >&2
fi

cat <<EOF
{
  "driver": {
    "name": "Slurm driver+enroot/apptainer",
    "version": "v0.0.1"
  },
"job_env": {
    "CE_QUEUE_WORKSPACE" : "$WORKSPACE"
  }
}
EOF
