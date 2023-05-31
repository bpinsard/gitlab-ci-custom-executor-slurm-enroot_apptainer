#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/containerlib-apptainer.sh
source "$SRC"/containerlib-apptainer.sh

echo "[PREPARE] Singularity: pulling image $CUSTOM_ENV_CI_JOB_IMAGE to $CE_IMAGEFILE" >&2

COMMAND=(apptainer
         pull
         "$CE_IMAGEFILE"
         "$CUSTOM_ENV_CI_JOB_IMAGE")

"${COMMAND[@]}" || {
    echo "ERROR: command failed: ${COMMAND[*]}";
    echo "       Image pull failed";
    }
