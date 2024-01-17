#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/include.sh
source "$SRC/include.sh"

function check_custom_env_ci_ws_set(){
    set +o nounset
    if [[ -z "$CUSTOM_ENV_CI_WS" ]]
    then
        echo "ERROR: CUSTOM_ENV_CI_WS variable not defined." >&2
        echo "       Please define the CI_WS variable in your gitlab CI/CD setup (See README)." >&2

        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi
    set -o nounset
}

function find_available_workspace_name(){

    ROOT="$1"
    ROOTDIR="$(dirname "$ROOT")"
    if [[ ! -d "$ROOTDIR" ]]
    then
        echo "Not an existing directory: $ROOTDIR" >&2
        return 22
    fi

    N=0;
    CANDIDATE="$ROOT$N"
    while ! mkdir "$CANDIDATE" &> /dev/null
    do
       N=$((N+1))
       CANDIDATE="$ROOT$N"
    done
    echo "$CANDIDATE"

}

