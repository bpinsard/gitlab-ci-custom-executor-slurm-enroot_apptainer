#!/usr/bin/env bash
# https://docs.gitlab.com/runner/executors/custom.html#config

# This script configures a slurm job
# using the slurm OCI support

if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
set -o nounset
set -o errexit
set -o pipefail

BACKEND="$1"
USESLURM="$2"
ALLOWED_GITLAB_USERS_FILE="${3:-}"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

#shellcheck source=./src/configure-include.sh
source "$SRC/configure-include.sh"

check_allowed_gitlab_user_list "$ALLOWED_GITLAB_USERS_FILE" "$CUSTOM_ENV_GITLAB_USER_LOGIN"





if [[ "$USESLURM" == "useslurm" ]]
then
    #shellcheck source=./src/configure-slurm-include.sh
    source "$SRC/configure-slurm-include.sh"

    check_custom_env_ci_ws_set

    export_all_slurm_custom_env_var_into_var_if_defined

    CI_BUILDS_DIR="$CUSTOM_ENV_CI_WS/$BACKEND/$CUSTOM_ENV_CI_CONCURRENT_ID"
    mkdir -p "$CI_BUILDS_DIR"

    WORKSPACE=$(determine_slurm_workspace "${CUSTOM_ENV_JOB_TIME_SEC:-600}" "${CUSTOM_ENV_REUSE_WORKSPACE:-ON}" )
    print_json_output_slurm "$CI_BUILDS_DIR" "$WORKSPACE"
fi

if [[ "$USESLURM" == "noslurm" ]]
then
    #shellcheck source=./src/configure-slurm-include.sh
    source "$SRC/configure-noslurm-include.sh"

    check_custom_env_ci_ws_set

    CI_BUILDS_DIR="$CUSTOM_ENV_CI_WS/$BACKEND/$CUSTOM_ENV_CI_CONCURRENT_ID"
    mkdir -p "$CI_BUILDS_DIR"

    print_json_output_noslurm "$CI_BUILDS_DIR"
fi
