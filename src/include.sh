#!/usr/bin/env bash

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

function validate_containerisation_backend(){

    local CONTAINERISATION_BACKEND="$1"
    local CI_JOB_IMAGE="$2"
    local IMAGEFILE="$3"

    if [ -n "$CI_JOB_IMAGE" ] || [ -n "$IMAGEFILE" ] && [ "$CONTAINERISATION_BACKEND" == "none" ]
    then
        echo "Error: Job requires a container image but 'none' selected as backend. "
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi
    case "$CONTAINERISATION_BACKEND" in
    enroot|apptainer|none)
        echo "Containerisation backend: $CONTAINERISATION_BACKEND" >&2
        ;;
    *)
        echo "Invalid containerisation backend: $CONTAINERISATION_BACKEND" >&2
        exit "$SYSTEM_FAILURE_EXIT_CODE"
        ;;
    esac

}
