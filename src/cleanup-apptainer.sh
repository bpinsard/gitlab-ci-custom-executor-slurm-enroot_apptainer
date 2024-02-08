#!/usr/bin/env bash


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/containerlib-apptainer.sh
source "$SRC"/containerlib-apptainer.sh

if [[ "${CUSTOM_ENV_CE_DEBUG_LVL:-0}" -lt 2 ]]  && [[ -z "${CUSTOM_ENV_IMAGEFILE:-}" ]]
then
    # In case this is a sandbox, we need to use rm -r
    # but I cowardly refuse to have rm -r in a script
    echo_verbose "[CLEANUP] Removing $CE_IMAGEFILE"
    rm "$CE_IMAGEFILE"
else
    echo_verbose "[CLEANUP] Not Removing $CE_IMAGEFILE because:"
    echo_verbose "[CLEANUP] - CE_DEBUG_LVL=${CUSTOM_ENV_CE_DEBUG_LVL:-}"
    echo_verbose "[CLEANUP] - IMAGEFILE=${CUSTOM_ENV_IMAGEFILE:-}"
fi
