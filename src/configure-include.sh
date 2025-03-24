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

function check_allowed_gitlab_user_list(){
    local ALLOWED_GITLAB_USERS_FILE="$1"
    local GITLAB_USER_LOGIN="$2"


    [ -n "$ALLOWED_GITLAB_USERS_FILE" ] || return 0

    echo "Checking if gitlab user $GITLAB_USER_LOGIN is in file $ALLOWED_GITLAB_USERS_FILE ..." >&2
     {
        {
            local FILE_OWNER_UID USER_ID
            FILE_OWNER_UID=$(stat -c "%u" "$ALLOWED_GITLAB_USERS_FILE")
            USER_ID=$(id -u)

            test "$USER_ID" == "$FILE_OWNER_UID"
        } || {

            echo "[CONFIGURE]: Error: $ALLOWED_GITLAB_USERS_FILE not owned by $USER" >&2
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        } } && {
        local PERMISSIONS
        PERMISSIONS=$(stat -c "%A" "$ALLOWED_GITLAB_USERS_FILE")
        if ! [[ "$PERMISSIONS" =~ -r...-..-. ]]
        then
            echo "[CONFIGURE]: Error: $ALLOWED_GITLAB_USERS_FILE has not the right permissions" >&2
            echo "                    it should not be writable by anybody else than the owner." >&2
            echo "                    (permissions: $PERMISSIONS)" >&2
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        fi

    } && {

        grep -Eq "^$GITLAB_USER_LOGIN$" "$ALLOWED_GITLAB_USERS_FILE"  || {
            echo "[CONFIGURE]: Error: $GITLAB_USER_LOGIN not in allowed gitlab user list." >&2;
            exit "$SYSTEM_FAILURE_EXIT_CODE";

        }
    }


}


function get_gitlab_username_from_job_token(){
  # Example from: https://docs.gitlab.com/api/jobs/#get-job-tokens-job
  curl --header "Authorization: Bearer $CUSTOM_ENV_CI_JOB_TOKEN" \
  --url "${CUSTOM_ENV_CI_API_V4_URL}/job" 2>/dev/null | jq .user.username  | tr -d '"'
}
