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
        echo "Containerisation backend: $CONTAINERISATION_BACKEND" >&2
        ;;
    *)
        echo "Invalid containerisation backend: $CONTAINERISATION_BACKEND" >&2
        exit "$SYSTEM_FAILURE_EXIT_CODE"
        ;;
    esac

}
