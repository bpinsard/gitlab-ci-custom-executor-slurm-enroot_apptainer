#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/singularity-containerlib.sh
source "$SRC"/singularity-containerlib.sh

COMMAND=(singularity
         pull
         "$CE_IMAGEFILE"
         docker://"$CUSTOM_ENV_CI_JOB_IMAGE")

"${COMMAND[@]}" || {
    echo "ERROR: command failed: ${COMMAND[*]}";
    echo "       Image pull failed";
    }
