#!/usr/bin/env bash

export ENROOT_RUNTIME_PATH="$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/run"
export ENROOT_CACHE_PATH="$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/cache"
export ENROOT_DATA_PATH="$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/data"

enroot import docker://"$CUSTOM_ENV_CI_JOB_IMAGE"

if { enroot list | grep "$CE_CONTAINER_NAME"; }
then enroot remove "$CE_CONTAINER_NAME" < <(echo yes)
fi
enroot create --name "$CE_CONTAINER_NAME"
