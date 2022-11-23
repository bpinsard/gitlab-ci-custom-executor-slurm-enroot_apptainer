#!/usr/bin/env bash

function assemble_mounts () {

    mapfile -t -d' ' MOUNT_DIRECTIVES  < <(for m in "$@"; do echo -n "$m:$m "; done )
    local IFS=','
    echo "${MOUNT_DIRECTIVES[*]}"

}


function export_custom_env_var_into_var_if_defined() {

    local VAR="$1"

    set +o nounset
    eval 'if [[ ! -z "$CUSTOM_ENV_'"$VAR"'" ]];
          then
            export '"$VAR"'="$CUSTOM_ENV_'"$VAR"'";
          fi; '
    set -o nounset

}

function check_custom_env_command_options_sbatch_for_forbidden_options(){
    FORBIDDEN_OPTIONS=("$@")
    for FORBIDDEN_OPTION in "${FORBIDDEN_OPTIONS[@]}"
    do
        echo "Checking $FORBIDDEN_OPTION" >&2
        if [[ "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH" =~ $FORBIDDEN_OPTION ]]
        then
            echo "Error: please do not use $FORBIDDEN_OPTION in \$COMMAND_OPTIONS_SBATCH." >&2
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        fi
    done

}
