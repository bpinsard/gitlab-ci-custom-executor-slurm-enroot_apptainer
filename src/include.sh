#!/usr/bin/env bash


function get_slurm_jobid(){
    (
    local WORKSPACE="$1"
    source "$WORKSPACE/.env"
    echo "$CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID"
    )
}


function allocation_is_alive(){

    local WORKSPACE="$1"

    JOBID="$(get_slurm_jobid "$WORKSPACE")"
    export JOBID

    squeue -j "$JOBID"  --Format=State,EndTime &> /dev/null

}
