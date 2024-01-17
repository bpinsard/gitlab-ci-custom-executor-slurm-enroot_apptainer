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

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"


if [[ "$USESLURM" == "useslurm" ]]
then
    #shellcheck source=./src/configure-slurm-include.sh
    source "$SRC/configure-slurm-include.sh"

    check_custom_env_ci_ws_set

    export_all_custom_env_var_into_var_if_defined # SLURM ONLY?

    WORKSPACE=$(look_for_workspace_with_suitable_slurm_allocation)

    if [ -z "$WORKSPACE" ]
    then
        echo "[CONFIGURE] No suitable workspace found." >&2
        WORKSPACE=$(create_new_slurm_workspace)
    fi

    CI_BUILDS_DIR="$CUSTOM_ENV_CI_WS/$BACKEND/$CUSTOM_ENV_CI_CONCURRENT_ID"
    mkdir -p "$CI_BUILDS_DIR"

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
