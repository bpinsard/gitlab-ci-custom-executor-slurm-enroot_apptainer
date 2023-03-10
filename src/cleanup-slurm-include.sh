#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=src/include.sh
source "$SRC"/include.sh


function terminate_slurm_allocation(){
    local SLURM_JOB_ID="$1"
    # "soft" cleanup
    scancel --batch --signal=SIGUSR1 -f "$SLURM_JOB_ID"
    sleep 5
    # "hard" cleanup - in case SIGUSR1 did not work
    scancel "$SLURM_JOB_ID"

}
