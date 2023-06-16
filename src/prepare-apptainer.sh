#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/containerlib-apptainer.sh
source "$SRC"/containerlib-apptainer.sh

echo "[PREPARE] Singularity: pulling image $CUSTOM_ENV_CI_JOB_IMAGE to $CE_IMAGEFILE" >&2

set +o nounset
if [ -z "$CUSTOM_ENV_IMAGEFILE" ]
then
    CUSTOM_ENV_IMAGEFILE=''
fi
set -o nounset


if [[ -z "$CUSTOM_ENV_IMAGEFILE" ]] || [[ ! -a "$CUSTOM_ENV_IMAGEFILE" ]]
then
    COMMAND=(apptainer
             pull
             "$CE_IMAGEFILE"
             "$CUSTOM_ENV_CI_JOB_IMAGE")

    "${COMMAND[@]}" || {
        echo "ERROR: command failed: ${COMMAND[*]}";
        echo "       Image pull failed";
        }
fi
