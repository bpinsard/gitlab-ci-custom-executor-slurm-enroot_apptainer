#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

CONTAINERISATION_BACKEND="${1}"
USESLURM="${2}"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

if [[ "$USESLURM" == "useslurm" ]]
then
    # shellcheck source=./src/slurm-include.sh
    source "$SRC/slurm-include.sh"
    echo_verbose  "[PREPARE] Using workspace $CE_QUEUE_WORKSPACE..." >&2
elif [[ "$USESLURM" == "noslurm" ]]
then
    # shellcheck source=./src/include.sh
    source "$SRC/include.sh"
fi



set +o nounset
[[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]] || export CUSTOM_ENV_CI_JOB_IMAGE=""
[[ -n "$CUSTOM_ENV_IMAGEFILE" ]] || export CUSTOM_ENV_IMAGEFILE=""
[[ -n "$CUSTOM_ENV_APPTAINER_DOCKER_USERNAME" ]] || export CUSTOM_ENV_APPTAINER_DOCKER_USERNAME=""
[[ -n "$CUSTOM_ENV_APPTAINER_DOCKER_PASSWORD" ]] || export CUSTOM_ENV_APPTAINER_DOCKER_PASSWORD=""
set -o nounset

# Both defined
if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]] && [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
then
    echo -n "image: $CUSTOM_ENV_CI_JOB_IMAGE"
    echo -n " and variable IMAGEFILE=$CUSTOM_ENV_IMAGEFILE"
    echo " are set at the same time."
    if [[ -e "$CUSTOM_ENV_IMAGEFILE" ]]
    then
        echo "$CUSTOM_ENV_IMAGEFILE does exist, not dowloading image: $CUSTOM_ENV_CI_JOB_IMAGE"
    fi
fi

# image: undefined but IMAGEFILE defined
if [[ -z "$CUSTOM_ENV_CI_JOB_IMAGE" ]] && [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
then
    if [[ ! -e "$CUSTOM_ENV_IMAGEFILE" ]]
    then
        echo "IMAGEFILE=$CUSTOM_ENV_IMAGEFILE does not exist and image: not specified."
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi
fi
echo_verbose -n "[PREPARE] "; validate_containerisation_backend \
                             "$CONTAINERISATION_BACKEND" \
                             "$CUSTOM_ENV_CI_JOB_IMAGE" \
                             "$CUSTOM_ENV_IMAGEFILE"



if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]] || [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
then
    echo_verbose  "[PREPARE] Using image $CUSTOM_ENV_CI_JOB_IMAGE" >&2

    case "$CONTAINERISATION_BACKEND" in
        enroot)
            PREPARE_SCRIPT="$SRC/prepare-enroot.sh"
            ;;
        apptainer)
            PREPARE_SCRIPT="$SRC/prepare-apptainer.sh"
            ;;
        *)
            echo_verbose "[PREPARE] Error: No valid container backend specified"
            echo_verbose "[PREPARE]        (i.e., apptainer or enroot)"
            echo_verbose "[PREPARE]        but job requires a container image."
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
export CUSTOM_ENV_CI_CONCURRENT_ID="$CUSTOM_ENV_CI_CONCURRENT_ID"
source "$PREPARE_SCRIPT"
EOF
    chmod +x "$WRAP"


    echo_verbose "[PREPARE] Wrap to be executed (credentials redacted):" >&2
    echo_verbose "==========================" >&2
    cat_verbose <(grep -vi "PASSWORD\|USERNAME" "$WRAP") >&2
    echo_verbose "==========================" >&2
    if [[ "$USESLURM" == "useslurm" ]]
    then
        # shellcheck source=./src/custom_executor_queue.sh
        source "$SRC/custom_executor_queue.sh"
        # shellcheck disable=SC1091
        source "$CE_QUEUE_WORKSPACE/.env"
       submit_to_custom_executor_queue_and_wait "$WRAP" "JOB_$CUSTOM_ENV_CI_JOB_ID"
    elif [[ "$USESLURM" == "noslurm" ]]
    then
             "$WRAP" "JOB_$CUSTOM_ENV_CI_JOB_ID"
    fi
else
    echo_verbose "[PREPARE] No image selected." >&2
fi
