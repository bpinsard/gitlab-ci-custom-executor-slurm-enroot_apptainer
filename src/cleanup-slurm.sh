#!/usr/bin/env bash

# "soft" cleanup
scancel --batch --signal=SIGUSR1 -f "$CE_SLURM_JOB_ID"
sleep 5
# "hard" cleanup - in case SIGUSR1 did not work
scancel "$CE_SLURM_JOB_ID"


if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then

    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
    # shellcheck source=./src/enroot-containerlib.sh
    source "$SRC"/enroot-containerlib.sh

    if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
    then
        enroot remove "$CE_CONTAINER_NAME" < <(echo yes)
    fi

    rm "$CE_IMAGEFILE"
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

