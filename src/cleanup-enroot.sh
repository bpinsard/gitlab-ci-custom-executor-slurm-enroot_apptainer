#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/containerlib-enroot.sh
source "$SRC"/containerlib-enroot.sh

set +o nounset
if [[ "${CUSTOM_ENV_CE_DEBUG_LVL:-0}" -gt 1 ]]
then
    echo_verbose "[CLEANUP] Debug Mode active"
else
    echo_verbose "[CLEANUP] Not in Debug Mode"
    echo_verbose "[CLEANUP] enroot remove $CE_CONTAINER_NAME"
    enroot remove "$CE_CONTAINER_NAME" < <(echo y)
fi
