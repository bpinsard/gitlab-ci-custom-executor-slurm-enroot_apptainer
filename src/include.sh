#!/usr/bin/env bash

function validate_containerisation_backend(){

    local CONTAINERISATION_BACKEND="$1"
    local CI_JOB_IMAGE="$2"
    local IMAGEFILE="$3"

    if [ -n "$CI_JOB_IMAGE" ] || [ -n "$IMAGEFILE" ] && [ "$CONTAINERISATION_BACKEND" == "none" ]
    then
        echo_verbose "Error: Job requires a container image but 'none' selected as backend. "
        echo_verbose "       image: $CI_JOB_IMAGE"
        echo_verbose "       imagefile: $IMAGEFILE"
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi
    case "$CONTAINERISATION_BACKEND" in
    enroot|apptainer|none)
        echo_verbose "Containerisation backend: $CONTAINERISATION_BACKEND" >&2
        ;;
    *)
        echo_verbose "Invalid containerisation backend: $CONTAINERISATION_BACKEND" >&2
        exit "$SYSTEM_FAILURE_EXIT_CODE"
        ;;
    esac

}


function echo_verbose() {
    if [ ! -z "${CUSTOM_ENV_VERBOSE_OUTPUT:-}" ]
    then
        echo $@
    fi
}


function cat_verbose() {
    if [ ! -z "${CUSTOM_ENV_VERBOSE_OUTPUT:-}" ]
    then
        cat $@
    fi
}
