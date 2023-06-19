#!/usr/bin/env bash

set +o nounset
if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]] || [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
then
    if [ -z "$ENROOT_RUNTIME_PATH" ]
    then
        export ENROOT_RUNTIME_PATH="$CUSTOM_ENV_CI_WS/$CUSTOM_ENV_CI_CONCURRENT_ID/.enroot/run"
    fi
    if [ -z "$ENROOT_CACHE_PATH" ]
    then
        export ENROOT_CACHE_PATH="$CUSTOM_ENV_CI_WS/.enroot/cache"
    fi
    if [ -z "$ENROOT_DATA_PATH" ]
    then
        export ENROOT_DATA_PATH="$CUSTOM_ENV_CI_WS/$CUSTOM_ENV_CI_CONCURRENT_ID/.enroot/data"
    fi
    export CE_CONTAINER_NAME="GLCE_$CUSTOM_ENV_CI_JOB_ID"
fi
set -o nounset
