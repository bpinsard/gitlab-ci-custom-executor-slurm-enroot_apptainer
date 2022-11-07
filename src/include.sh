#!/usr/bin/env bash

function assemble_mounts () {

    mapfile -t -d' ' MOUNT_DIRECTIVES  < <(for m in "$@"; do echo -n "$m:$m "; done )
    local IFS=','
    echo "${MOUNT_DIRECTIVES[*]}"

}

