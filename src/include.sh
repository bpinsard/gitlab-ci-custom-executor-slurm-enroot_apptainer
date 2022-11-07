#!/usr/bin/env bash

function assemble_mounts () {

    mapfile -t -d' ' MOUNT_DIRECTIVES  < <(for m in "$@"; do echo -n "$m:$m "; done )
    local IFS=','
    echo "${MOUNT_DIRECTIVES[*]}"

}


function export_custom_env_var_into_var_if_defined() {

    local VAR="$1"

    eval 'if [[ ! -z "$CUSTOM_ENV_'"$VAR"'" ]];
          then
            export '"$VAR"'="$CUSTOM_ENV_'"$VAR"'";
          fi; '

}
