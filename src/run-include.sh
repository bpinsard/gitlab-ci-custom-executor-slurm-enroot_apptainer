#!/usr/bin/env bash

function get_abs_path(){

    echo "$(export CDPATH=""; cd "$(dirname "$1")" || exit; pwd -P)"/"$(basename "$1")"
}
