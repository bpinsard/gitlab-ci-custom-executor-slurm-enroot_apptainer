#!/usr/bin/env bash

if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    export SINGULARITY_CACHEDIR="$CUSTOM_ENV_CI_WS/.singularity"
    export CE_IMAGEFILE="$CUSTOM_ENV_CI_WS/image-$CUSTOM_ENV_CI_JOB_ID.sif"
fi
