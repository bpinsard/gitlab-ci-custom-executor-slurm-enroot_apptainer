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

function check_allowed_committer_list(){


    { test -z "${CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE:-}"  && {

          test "$CUSTOM_ENV_GITLAB_USER_LOGIN" == "$USER" || {

              echo "[CONFIGURE]: Error: $CUSTOM_ENV_GITLAB_USER_LOGIN is not $USER" >&2
              echo "             CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE undefined" >&2
              exit "$SYSTEM_FAILURE_EXIT_CODE"

          } } } ||  { {

        {
            local FILE_OWNER_UID USER_ID
            FILE_OWNER_UID=$(stat -c "%u" "$CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE")
            USER_ID=$(id -u)

            test "$USER_ID" == "$FILE_OWNER_UID"
        } || {

            echo "[CONFIGURE]: Error: $CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE not owned by $USER" >&2
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        } } && {
        local PERMISSIONS
        PERMISSIONS=$(stat -c "%A" "$CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE")
        if ! [[ "$PERMISSIONS" =~ -r...-..-. ]]
        then
            echo "[CONFIGURE]: Error: $CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE has not the right permissions" >&2
            echo "                    it should not be writable by anybody else than the owner." >&2
            echo "                    (permissions: $PERMISSIONS)" >&2
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        fi

    } && {

        grep -wq "$CUSTOM_ENV_GITLAB_USER_LOGIN" "$CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE"  || {
            echo "[CONFIGURE]: Error: $CUSTOM_ENV_GITLAB_USER_LOGIN not in allowed committer list." >&2;
            exit "$SYSTEM_FAILURE_EXIT_CODE";

        }
    }
    }

}
