#!/usr/bin/env bash

function has_slurm_job_id(){
    (
    local WORKSPACE="$1"
    grep -q CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID "$WORKSPACE/.env"
    )
}

function get_slurm_jobid(){
    (
    local WORKSPACE="$1"
    # shellcheck disable=SC1091
    source "$WORKSPACE/.env"
    echo "$CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID"
    )
}


function allocation_is_alive(){

    local WORKSPACE="$1"

    if has_slurm_job_id "$WORKSPACE"
    then
        JOBID="$(get_slurm_jobid "$WORKSPACE")"
        squeue -j "$JOBID"  --Format=State,EndTime &> /dev/null
    fi

}
