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

    enroot import docker://"$CUSTOM_ENV_CI_JOB_IMAGE"

    if { enroot list | grep "$CE_CONTAINER_NAME"; }
    then enroot remove "$CE_CONTAINER_NAME" < <(echo yes)
    fi
    enroot create --name "$CE_CONTAINER_NAME"
fi
