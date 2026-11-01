#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/containerlib-apptainer.sh
source "$SRC"/containerlib-apptainer.sh
# shellcheck source=./src/include.sh
source "$SRC"/include.sh

echo_verbose "[PREPARE] Apptainer: pulling image $CUSTOM_ENV_CI_JOB_IMAGE to $CE_IMAGEFILE" >&2

set +o nounset
if [ -z "$CUSTOM_ENV_IMAGEFILE" ]
then
    CUSTOM_ENV_IMAGEFILE=''
fi
set -o nounset


if [[ -z "$CUSTOM_ENV_IMAGEFILE" ]] || [[ ! -e "$CUSTOM_ENV_IMAGEFILE" ]]
then
    # GitLab's `image:` is a bare docker reference (e.g. alpine:latest),
    # while apptainer needs an explicit transport.
    IMAGE_REF="$CUSTOM_ENV_CI_JOB_IMAGE"
    if [[ ! "$IMAGE_REF" =~ ^(docker|oras|library|shub|http|https)://  ]] &&
       [[ ! "$IMAGE_REF" =~ ^(docker-archive|docker-daemon|oci|oci-archive|sif|dir): ]]
    then
        IMAGE_REF="docker://$IMAGE_REF"
    fi

    COMMAND=(apptainer
             pull
             "$CE_IMAGEFILE"
             "$IMAGE_REF")

    echo_verbose "[PREPARE] Command: ${COMMAND[*]}" >&2
    "${COMMAND[@]}" || {
        echo "ERROR: command failed: ${COMMAND[*]}";
        echo "       Image pull failed";
        exit 1
        }
fi
