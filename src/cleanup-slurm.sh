#!/usr/bin/env bash

CONTAINERISATION_BACKEND="${1}"

# "soft" cleanup
scancel --batch --signal=SIGUSR1 -f "$CE_SLURM_JOB_ID"
sleep 5
# "hard" cleanup - in case SIGUSR1 did not work
scancel "$CE_SLURM_JOB_ID"


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
            ;;
    esac
fi

# shellcheck disable=SC1090
source "$CE_QUEUE_ENV_PATH"


# End lifetime of the CE queue workspace
if [[ -n "$CUSTOM_ENV_CE_DEBUG" ]]
then
   mkdir -p "$HOME/ce-debug/"
   mv  "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE" "$HOME/ce-debug/""cews_$CUSTOM_ENV_CI_JOB_ID"
else
   rm -r "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"
fi

