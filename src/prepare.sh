#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/include.sh
source "$SRC/include.sh"

echo  "[PREPARE] Using workspace $CE_QUEUE_WORKSPACE..." >&2

CONTAINERISATION_BACKEND="${1}"

if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]] && [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
then
    echo -n "ERROR: image: option ($CUSTOM_ENV_CI_JOB_IMAGE) "
    echo "and IMAGEFILE variable ($CUSTOM_ENV_IMAGEFILE) set at the same time"
    exit "$SYSTEM_FAILURE_EXIT_CODE"
fi

echo -n "[PREPARE] "; validate_containerisation_backend "$CONTAINERISATION_BACKEND" "$CUSTOM_ENV_CI_JOB_IMAGE"

if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]] || [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
then
    echo  "[PREPARE] Using image $CUSTOM_ENV_CI_JOB_IMAGE" >&2

    case "$CONTAINERISATION_BACKEND" in
        enroot)
            PREPARE_SCRIPT="$SRC/prepare-enroot.sh"
            ;;
        apptainer)
            PREPARE_SCRIPT="$SRC/prepare-apptainer.sh"
            ;;
        *)
            echo "[PREPARE] Error: No valid container backend specified"
            echo "[PREPARE]        (i.e., apptainer or enroot)"
            echo "[PREPARE]        but job requires a container image."
            exit 22
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
export APPTAINER_DOCKER_USERNAME="$CUSTOM_ENV_APPTAINER_DOCKER_USERNAME" # TODO: add test
export APPTAINER_DOCKER_PASSWORD="$CUSTOM_ENV_APPTAINER_DOCKER_PASSWORD" # TODO: add test
export CUSTOM_ENV_CI_JOB_IMAGE="$CUSTOM_ENV_CI_JOB_IMAGE"
export CUSTOM_ENV_IMAGEFILE="$CUSTOM_ENV_IMAGEFILE"
export CUSTOM_ENV_CI_JOB_ID="$CUSTOM_ENV_CI_JOB_ID"
source "$PREPARE_SCRIPT"
EOF
    chmod +x "$WRAP"

    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    echo "[PREPARE] Wrap to be executed (credentials redacted):" >&2
    echo "==========================" >&2
    grep -vi "PASSWORD\|USERNAME" "$WRAP" >&2
    echo "==========================" >&2
    submit_to_custom_executor_queue_and_wait "$WRAP" "JOB_$CUSTOM_ENV_CI_JOB_ID"
else
    echo "[PREPARE] No image selected." >&2
fi
