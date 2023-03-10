#!/usr/bin/env bash

CONTAINERISATION_BACKEND="${1}"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=src/cleanup-slurm-include.sh
source "$SRC"/cleanup-slurm-include.sh


# TODO: This should not happen anymore
terminate_slurm_allocation "$CE_SLURM_JOB_ID"

if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"


    case "$CONTAINERISATION_BACKEND" in
        enroot)
            # shellcheck source=./src/enroot-cleanup.sh
            source "$SRC/enroot-cleanup.sh"
            ;;
        singularity)
            # shellcheck source=./src/singularity-cleanup.sh
            source "$SRC/singularity-cleanup.sh"
            ;;
        *)
            echo "ERROR: Not a valid backend: $CONTAINERISATION_BACKEND"
            exit "$SYSTEM_FAILURE_EXIT_CODE"
            ;;
    esac
fi

# shellcheck disable=SC1090
source "$CE_QUEUE_ENV_PATH"


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
set -o nounset

if [[ "$DEBUG" == "YES" ]]
then
   mkdir -p "$CUSTOM_ENV_CE_DEBUG_DIR"
   # TODO: Change this, this move cannot happen now at the end of the job,
   #       it must happen at the end of the pipeline
   mv  "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE" "$CUSTOM_ENV_CE_DEBUG_DIR/cews_$CUSTOM_ENV_CI_JOB_ID"
else
   rm -r "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"
fi

