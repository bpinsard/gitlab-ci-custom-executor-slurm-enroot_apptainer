#!/usr/bin/env bash


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/singularity-containerlib.sh
source "$SRC"/singularity-containerlib.sh


set +o nounset
if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
then
    DEBUG="YES"
else
    DEBUG="NO"
fi
set -o nounset

if [[ "$DEBUG" == "YES" ]]
then
    # In case this is a sandbox, we need to use rm -r
    # but I cowardly refuse to have rm -r in a script
    echo "Removing $CE_IMAGEFILE"
    rm "$CE_IMAGEFILE"
fi
