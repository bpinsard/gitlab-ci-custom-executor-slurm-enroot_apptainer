#!/usr/bin/env bash

function validate_containerisation_backend(){

    local CONTAINERISATION_BACKEND="$1"
    local CI_JOB_IMAGE="$2"
    local IMAGEFILE="$3"

    if [ -n "$CI_JOB_IMAGE" ] || [ -n "$IMAGEFILE" ] && [ "$CONTAINERISATION_BACKEND" == "none" ]
    then
        echo "Error: Job requires a container image but 'none' selected as backend. "
        echo "       image: $CI_JOB_IMAGE"
        echo "       imagefile: $IMAGEFILE"
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi
    case "$CONTAINERISATION_BACKEND" in
    enroot|apptainer|none)
        echo_verbose "Containerisation backend: $CONTAINERISATION_BACKEND" >&2
        ;;
    *)
        echo "Error: Invalid containerisation backend: $CONTAINERISATION_BACKEND" >&2
        exit "$SYSTEM_FAILURE_EXIT_CODE"
        ;;
    esac

}


function echo_verbose() {
    if [ "${CUSTOM_ENV_CE_DEBUG_LVL:-0}" -gt 0 ]
    then
        echo "$@"
    fi
}


function cat_verbose() {
    if [ "${CUSTOM_ENV_CE_DEBUG_LVL:-0}" -gt 0 ]
    then
        cat "$@"
    fi
}
