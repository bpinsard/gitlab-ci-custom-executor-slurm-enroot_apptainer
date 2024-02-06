#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/containerlib-enroot.sh
source "$SRC"/containerlib-enroot.sh

DEBUG=""
set +o nounset
if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
then
    echo_verbose "[CLEANUP] Not in Debug Mode"
    DEBUG="NO"
else
    echo_verbose "[CLEANUP] Debug Mode active"
    DEBUG="YES"
fi
set -o nounset

if [[ "$DEBUG" == "NO" ]]
then
    echo_verbose "[CLEANUP] enroot remove $CE_CONTAINER_NAME"
    enroot remove "$CE_CONTAINER_NAME" < <(echo y)
fi
