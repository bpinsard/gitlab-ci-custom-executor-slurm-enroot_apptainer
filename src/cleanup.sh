#!/usr/bin/env bash

echo "[CLEANUP] Cleaning up..." >&2
CONTAINERISATION_BACKEND="${1}"
USESLURM="${2}"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

if [[ "$USESLURM" == "useslurm" ]]
then
    # shellcheck source=src/cleanup-slurm-include.sh
    source "$SRC"/cleanup-slurm-include.sh

    SLURMENV_CANDIDATE="$CUSTOM_ENV_CI_WS/slurmenv_candidate_$CUSTOM_ENV_CI_JOB_ID"
    if [ -f "$SLURMENV_CANDIDATE" ]
    then
        rm "$SLURMENV_CANDIDATE"
    fi

    # End lifetime of the CE queue workspace
    set +o nounset
    if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
    then
        DEBUG="NO"
    else
       DEBUG="YES"
    fi

    if [[ -z "$CUSTOM_ENV_CE_DEBUG_DIR" ]]
    then
        CUSTOM_ENV_CE_DEBUG_DIR="$HOME/ce-debug"
    fi

    if [[ "$CUSTOM_ENV_KILL_SLURM" -eq 1 ]] && has_slurm_job_id "$CE_QUEUE_WORKSPACE"
    then
        KILL_SLURM="YES"
    else
       KILL_SLURM="NO"
    fi
    set -o nounset

    remove_old_workspaces
    terminate_slurm_allocation_if_required "$KILL_SLURM"
    backup_ce_workspace_if_debug "$DEBUG"
    cleanup_ce_job_group

elif [[ "$USESLURM" == "noslurm" ]]
then
    # shellcheck source=src/cleanup-include.sh
    source "$SRC"/cleanup-include.sh
fi

set +o nounset
if [[ -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    export CUSTOM_ENV_CI_JOB_IMAGE=""
fi
if [ -z "$CUSTOM_ENV_IMAGEFILE" ]
then
    CUSTOM_ENV_IMAGEFILE=''
fi
set -o nounset
cleanup_containers "$CONTAINERISATION_BACKEND"
