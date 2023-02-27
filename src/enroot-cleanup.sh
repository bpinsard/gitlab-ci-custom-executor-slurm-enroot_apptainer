#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/enroot-containerlib.sh
source "$SRC"/enroot-containerlib.sh

DEBUG=""
set +o nounset
if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
then
    DEBUG="YES"
else
    DEBUG="NO"
fi
set -o nounset

if [[ "$DEBUG" == "YES" ]]
then
    enroot remove "$CE_CONTAINER_NAME" < <(echo yes)
fi
