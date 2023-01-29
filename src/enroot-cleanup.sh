#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/enroot-containerlib.sh
source "$SRC"/enroot-containerlib.sh

if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
then
    enroot remove "$CE_CONTAINER_NAME" < <(echo yes)
fi

rm "$CE_IMAGEFILE"
