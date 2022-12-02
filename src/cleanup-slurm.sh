#!/usr/bin/env bash

# "soft" cleanup
scancel --batch --signal=SIGUSR1 -f "$CE_SLURM_JOB_ID"
sleep 5
# "hard" cleanup - in case SIGUSR1 did not work
scancel "$CE_SLURM_JOB_ID"


# shellcheck disable=SC1090
source "$CE_CUSTOM_EXECUTOR_QUEUE_ENV_PATH"

rm -r "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"
