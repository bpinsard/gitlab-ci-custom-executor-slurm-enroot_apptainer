#!/usr/bin/env bash

export SINGULARITY_CACHEDIR="$CUSTOM_ENV_CI_WS/singularity"
export CE_IMAGEFILE="$CUSTOM_ENV_CI_WS/image-$CUSTOM_ENV_CI_JOB_ID.sif"

singularity pull "$CE_IMAGEFILE" docker://"$CUSTOM_ENV_CI_JOB_IMAGE"
