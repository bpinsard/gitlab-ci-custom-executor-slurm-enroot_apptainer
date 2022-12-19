#!/usr/bin/env bash
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/containerlib.sh
source "$SRC"/containerlib.sh


if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    CE_IMAGEFILE="$CUSTOM_ENV_CI_BUILDS_DIR/image_${CE_CONTAINER_NAME}.sqsh"
    rm "$CE_IMAGEFILE"
    enroot import --output "$CE_IMAGEFILE" docker://"$CUSTOM_ENV_CI_JOB_IMAGE"

    if { enroot list | grep "$CE_CONTAINER_NAME"; }
    then enroot remove "$CE_CONTAINER_NAME" < <(echo yes)
    fi
    enroot create --name "$CE_CONTAINER_NAME" "$CE_IMAGEFILE"
fi
