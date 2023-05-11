#!/usr/bin/env bash
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/containerlib-enroot.sh
source "$SRC"/containerlib-enroot.sh

CE_IMAGEDIR="$(mktemp -d "$CUSTOM_ENV_CI_WS/imagedirXXXXX")"

# shellcheck disable=SC2064
trap "rm -rf $CE_IMAGEDIR" exit


set -o errexit

CE_IMAGEFILE="$CE_IMAGEDIR"/image.sqsh

echo "[PREPARE] Enroot: pulling image $CUSTOM_ENV_CI_JOB_IMAGE to $CE_IMAGEFILE" >&2

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
enroot create --name "$CE_CONTAINER_NAME" "$CE_IMAGEFILE"
