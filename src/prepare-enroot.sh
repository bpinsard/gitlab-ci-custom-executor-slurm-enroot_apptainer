#!/usr/bin/env bash
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/containerlib.sh
source "$SRC"/containerlib.sh


if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    IMAGEFILE="image_${CE_CONTAINER_NAME}.sqsh"
    rm "$IMAGEFILE"
    enroot import --output "$IMAGEFILE" docker://"$CUSTOM_ENV_CI_JOB_IMAGE"

    if { enroot list | grep "$CE_CONTAINER_NAME"; }
    then enroot remove "$CE_CONTAINER_NAME" < <(echo yes)
    fi
    enroot create --name "$CE_CONTAINER_NAME" "$IMAGEFILE"
fi
