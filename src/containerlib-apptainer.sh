#!/usr/bin/env bash

set +o nounset
if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    export APPTAINER_CACHEDIR="$CUSTOM_ENV_CI_WS/.apptainer"
    export CE_IMAGEFILE="$CUSTOM_ENV_CI_WS/image-$CUSTOM_ENV_CI_JOB_ID.sif"
fi

if [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
then
    export APPTAINER_CACHEDIR="$CUSTOM_ENV_CI_WS/.apptainer"
    export CE_IMAGEFILE="$CUSTOM_ENV_IMAGEFILE"
fi
set -o nounset
