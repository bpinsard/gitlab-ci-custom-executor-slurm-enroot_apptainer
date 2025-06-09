#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/include.sh
source "$SRC/include.sh"

function has_ce_env(){
    local WORKSPACE="$1"
    [ -f "$WORKSPACE/.env" ]

}

function has_slurm_job_id(){
    local WORKSPACE="$1"
    has_ce_env "$WORKSPACE" &&
    grep -q CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID "$WORKSPACE/.env"
}

function get_slurm_jobid(){
    local WORKSPACE="$1"
    # shellcheck disable=SC1091
    source "$WORKSPACE/.env"
    echo "$CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID"
}


function allocation_is_alive(){

    local WORKSPACE="$1"

    has_slurm_job_id "$WORKSPACE" && {
        JOBID="$(get_slurm_jobid "$WORKSPACE")"
        squeue -j "$JOBID"  --Format=State,EndTime &> /dev/null
    }

}

function allocation_is_starting(){

    local WORKSPACE="$1"
    [ -d "$WORKSPACE" ] && [ ! -f "$WORKSPACE/.env" ]

}
