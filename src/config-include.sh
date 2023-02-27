#!/usr/bin/env bash

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


function wait_until_file_exists() {
    local FILE="$1"
    local MAXDELAY="$2"
    local T0="$SECONDS"
    if [ "$#" -ne 2 ]
    then 
	    echo "wrong number of arguments to ${FUNCNAME[0]}" >&2
	    exit 22
    fi
    while [[ ! -f "$FILE" && "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done
    if [[ !  -f "$FILE" ]]
    then
        echo "Error: Waited too long ($MAXDELAY) for $FILE to be created".
        return 124
    fi

}
