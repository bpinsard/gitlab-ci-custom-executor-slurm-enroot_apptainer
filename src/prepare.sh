#!/usr/bin/env bash

echo  "[PREPARE] Using workspace $CE_QUEUE_WORKSPACE..." >&2

if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    echo  "[PREPARE] Using image $CUSTOM_ENV_CI_JOB_IMAGE" >&2
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

    CONTAINERISATION_BACKEND="${1}"
    case "$CONTAINERISATION_BACKEND" in
        enroot)
            echo "[PREPARE] Using Enroot backend..." >&2
            SCRIPT="$SRC/prepare-enroot.sh"
            ;;
        singularity)
            echo "[PREPARE] Using Singularity backend..." >&2
            SCRIPT="$SRC/prepare-singularity.sh"
            ;;
        *)
            ;;
    esac
    WRAP="./wrap-prepare-$CUSTOM_ENV_CI_JOB_ID.sh"

    # We cannot submit the scripts as they are
    # because the custom executor queue logic
    # will change their location,
    # then BASH_SOURCE[0] will not point to the original location
    # when they are executed
    # and they will not be able to find
    # the other scripts in the repository.
    cat <<EOF > "$WRAP"
#!/bin/bash
"$SCRIPT"
EOF
    chmod +x "$WRAP"

    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    submit_to_custom_executor_queue_and_wait "$WRAP" "JOB_$CUSTOM_ENV_CI_JOB_ID"
else
    echo "[PREPARE] No image selected." >&2
fi
