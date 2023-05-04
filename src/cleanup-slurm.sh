#!/usr/bin/env bash

echo "[CLEANUP] Cleaning up..." >&2
CONTAINERISATION_BACKEND="${1}"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
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

if [[ -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    export CUSTOM_ENV_CI_JOB_IMAGE=""
fi
set -o nounset


echo "[CLEANUP] Removing old workspaces..." >&2
shopt -s nullglob
for DIR in "$CUSTOM_ENV_CI_WS"/cews_*
do
    if ! allocation_is_alive "$DIR" && [[ "$DIR" != "$CE_QUEUE_WORKSPACE" ]]
    then
       if [ "$DEBUG" == "YES" ]
       then
           echo "[CLEANUP] Moving old workspace $DIR to $CUSTOM_ENV_CE_DEBUG_DIR for further inspection..." >&2

           mkdir -p "$CUSTOM_ENV_CE_DEBUG_DIR"
           rm -r "${CUSTOM_ENV_CE_DEBUG_DIR:?}/$(basename "$DIR")"
           mv "$DIR" "$CUSTOM_ENV_CE_DEBUG_DIR"
       else
           echo "[CLEANUP] Removing old workspace $DIR..." >&2
           rm -r "$DIR"
       fi
    fi
done
shopt -u nullglob



echo -n "[CLEANUP] "; validate_containerisation_backend "$CONTAINERISATION_BACKEND" "$CUSTOM_ENV_CI_JOB_IMAGE"

if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"


    case "$CONTAINERISATION_BACKEND" in
        enroot)
            echo "[CLEANUP] Invoking cleanup for $CONTAINERISATION_BACKEND"
            # shellcheck source=./src/enroot-cleanup.sh
            source "$SRC/enroot-cleanup.sh"
            ;;
        singularity)
            echo "[CLEANUP] Invoking cleanup for $CONTAINERISATION_BACKEND"
            # shellcheck source=./src/singularity-cleanup.sh
            source "$SRC/singularity-cleanup.sh"
            ;;
        *)
            echo "[CLEANUP] ERROR: Not a valid backend: $CONTAINERISATION_BACKEND"
            exit "$SYSTEM_FAILURE_EXIT_CODE"
            ;;
    esac
fi

if [[ "$KILL_SLURM" == "YES" ]]
then
   echo "[CLEANUP] Terminating slurm allocation in $CE_QUEUE_WORKSPACE" >&2
   terminate_slurm_allocation "$(get_slurm_jobid "$CE_QUEUE_WORKSPACE")"
fi
if [[ "$DEBUG" == "YES" ]]
then
   cp -r "$CE_QUEUE_WORKSPACE" "$CUSTOM_ENV_CE_DEBUG_DIR/"
fi

# shellcheck source=./src/custom_executor_queue.sh
source "$SRC/custom_executor_queue.sh"
# shellcheck disable=SC1091
source "$CE_QUEUE_WORKSPACE/.env"

request_cancel_job_group "JOB_$CUSTOM_ENV_CI_JOB_ID"
