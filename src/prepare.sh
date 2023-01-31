#!/usr/bin/env bash


if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

    CONTAINERISATION_BACKEND="${1}"
    case "$CONTAINERISATION_BACKEND" in
        enroot)
            SCRIPT="$SRC/prepare-enroot.sh"
            ;;
        singularity)
            SCRIPT="$SRC/prepare-singularity.sh"
            ;;
        *)
            ;;
    esac

    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"
    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"

    submit_to_custom_executor_queue_and_wait "$SCRIPT"
fi
