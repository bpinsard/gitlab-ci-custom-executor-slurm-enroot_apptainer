#!/usr/bin/env bash

if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    if [ -z "$ENROOT_RUNTIME_PATH" ]
    then
        export ENROOT_RUNTIME_PATH="$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/run"
    fi
    if [ -z "$ENROOT_CACHE_PATH" ]
    then
        export ENROOT_CACHE_PATH="$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/cache"
    fi
    if [ -z "$ENROOT_DATA_PATH" ]
    then
        export ENROOT_DATA_PATH="$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/data"
    fi
    export CE_CONTAINER_NAME="GLCE_$CUSTOM_ENV_CI_JOB_ID"
fi
