#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

function get_abs_path(){
    echo "$(export CDPATH=""; cd "$(dirname "$1")" || exit; pwd)"/"$(basename "$1")"
}

function nowrap(){
    echo "$@"
}

function wrap_enroot(){
    local SCRIPT="$1"
    "$SRC"/script-enroot-wrapper.sh "$(get_abs_path "$SCRIPT")" > "$SCRIPT"-wrapped.sh
    chmod +x "$SCRIPT"-wrapped.sh 1>&2
    echo "$SCRIPT"-wrapped.sh
}

function wrap_singularity(){
    local SCRIPT="$1"
    "$SRC"/script-singularity-wrapper.sh "$(get_abs_path "$SCRIPT")" > "$SCRIPT"-wrapped.sh
    chmod +x "$SCRIPT"-wrapped.sh 1>&2
    echo "$SCRIPT"-wrapped.sh
}
