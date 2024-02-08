#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/containerlib-enroot.sh
source "$SRC"/containerlib-enroot.sh
# shellcheck source=./src/include.sh
source "$SRC"/include.sh

CE_IMAGEDIR="$(mktemp -d "$CUSTOM_ENV_CI_WS/imagedirXXXXX")"

# shellcheck disable=SC2064
trap "rm -rf $CE_IMAGEDIR" exit


set +o nounset
if [ -z "$CUSTOM_ENV_IMAGEFILE" ]
then
    CUSTOM_ENV_IMAGEFILE=""
fi
set -o nounset

set -o errexit

if [[ -z "$CUSTOM_ENV_IMAGEFILE" ]] || [[ ! -a "$CUSTOM_ENV_IMAGEFILE" ]]
then
    if [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
    then
        CE_IMAGEFILE="$CUSTOM_ENV_IMAGEFILE"
    else
        CE_IMAGEFILE="$CE_IMAGEDIR"/image.sqsh
    fi

    echo_verbose "[PREPARE] Enroot: pulling image $CUSTOM_ENV_CI_JOB_IMAGE to $CE_IMAGEFILE" >&2

    COMMAND=(enroot
             import
             --output
             "$CE_IMAGEFILE"
             "$CUSTOM_ENV_CI_JOB_IMAGE")

    "${COMMAND[@]}" || {
        echo "ERROR: command failed: ${COMMAND[*]}";
        echo "       Image pull failed";
        }
    if { enroot list | grep "$CE_CONTAINER_NAME" &> /dev/null; }
    then enroot remove "$CE_CONTAINER_NAME" < <(echo yes)
    fi
else
    CE_IMAGEFILE="$CUSTOM_ENV_IMAGEFILE"
fi
enroot create --name "$CE_CONTAINER_NAME" "$CE_IMAGEFILE"
