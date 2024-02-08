#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=src/cleanup-include.sh
source "$SRC"/cleanup-include.sh

# shellcheck source=src/slurm-include.sh
source "$SRC"/slurm-include.sh

function terminate_slurm_allocation () {
    local SLURM_JOB_ID="$1"
    # "soft" cleanup
    scancel --batch --signal=SIGUSR1 -f "$SLURM_JOB_ID"
    sleep 5
    # "hard" cleanup - in case SIGUSR1 did not work
    scancel "$SLURM_JOB_ID"

}


function remove_old_workspaces(){
    echo_verbose "[CLEANUP] Removing old workspaces..." >&2
    local CUSTOM_ENV_CE_DEBUG_DIR="${CUSTOM_ENV_CE_DEBUG_DIR:-$HOME/ce-debug}/"
    shopt -s nullglob
    for DIR in "$CUSTOM_ENV_CI_WS"/cews_*
    do
        if ! allocation_is_alive "$DIR" && [[ "$DIR" != "$CE_QUEUE_WORKSPACE" ]]
        then
           if [ "${CUSTOM_ENV_CE_DEBUG_LVL:-0}" -gt 1 ]
           then
               echo "[CLEANUP] Moving old workspace $DIR to $CUSTOM_ENV_CE_DEBUG_DIR for further inspection..." >&2

               mkdir -p "$CUSTOM_ENV_CE_DEBUG_DIR"
               rm -r "${CUSTOM_ENV_CE_DEBUG_DIR:?}/$(basename "$DIR")"
               mv "$DIR" "$CUSTOM_ENV_CE_DEBUG_DIR"
           else
               echo_verbose "[CLEANUP] Removing old workspace $DIR..." >&2
               rm -r "$DIR"
           fi
        fi
    done
    shopt -u nullglob
}

function terminate_slurm_allocation_if_required() {

    local KILL_SLURM="$1"
    if [[ "$KILL_SLURM" == "YES" ]]
    then
       echo "[CLEANUP] Terminating slurm allocation in $CE_QUEUE_WORKSPACE" >&2
       terminate_slurm_allocation "$(get_slurm_jobid "$CE_QUEUE_WORKSPACE")"
    fi

}

function cleanup_ce_job_group() {
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    request_cancel_job_group "JOB_$CUSTOM_ENV_CI_JOB_ID"
}

function backup_ce_workspace_if_debug() {
    local DEBUG_LVL="$1"
    if [[ "$DEBUG_LVL" -gt "1" ]]
    then
       cp -r "$CE_QUEUE_WORKSPACE" "${CUSTOM_ENV_CE_DEBUG_DIR:-$HOME/ce-debug}/"
    fi
}
