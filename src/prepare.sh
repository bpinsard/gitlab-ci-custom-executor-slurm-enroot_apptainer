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

    # We cannot submit the scripts as they are
    # because the custom executor queue logic
    # will change their location,
    # then BASH_SOURCE[0] will not point to the original location
    # when they are executed
    # and they will not be able to find
    # the other scripts in the repository.
    cat <<EOF > ./wrap.sh
#!/bin/bash
"$SCRIPT"
EOF
    chmod +x ./wrap.sh

    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"
    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"

    submit_to_custom_executor_queue_and_wait ./wrap.sh
fi
