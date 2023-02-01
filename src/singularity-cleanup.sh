#!/usr/bin/env bash


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/singularity-containerlib.sh
source "$SRC"/singularity-containerlib.sh


if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
then
    # In case this is a sandbox, we need to use rm -r
    # but I cowardly refuse to have rm -r in a script
    rm "$CE_IMAGEFILE"
fi
