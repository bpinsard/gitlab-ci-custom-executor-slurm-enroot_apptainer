#!/usr/bin/env bash


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/containerlib-apptainer.sh
source "$SRC"/containerlib-apptainer.sh


set +o nounset
if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
then
    DEBUG="NO"
else
    DEBUG="YES"
fi
if [[ -z "$CUSTOM_ENV_IMAGEFILE" ]]
then
    export CUSTOM_ENV_IMAGEFILE=""
fi
set -o nounset

if [[ "$DEBUG" == "NO" ]]  && [[ -z "$CUSTOM_ENV_IMAGEFILE" ]]
then
    # In case this is a sandbox, we need to use rm -r
    # but I cowardly refuse to have rm -r in a script
    echo "[CLEANUP] Removing $CE_IMAGEFILE"
    rm "$CE_IMAGEFILE"
else
    echo "[CLEANUP] Not Removing $CE_IMAGEFILE because:"
    echo "[CLEANUP] - DEBUG=$DEBUG"
    echo "[CLEANUP] - IMAGEFILE=$CUSTOM_ENV_IMAGEFILE"
fi
