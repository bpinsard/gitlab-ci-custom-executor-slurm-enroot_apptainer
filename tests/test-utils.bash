#!/usr/bin/env bash

function json_validate () {
    python3 -c 'import json,sys;json.load(sys.stdin)' || ( echo "JSON validation failed" && exit 1 )
}

function wait_until_file_exists() {
    local FILE="$1"
    local MAXDELAY="$2"
    local T0="$SECONDS"
    while [[ ! -f "$FILE" && "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done

}

function wait_until_file_contains() {
    local FILE="$1"
    local WHAT="$2"
    local MAXDELAY="$3"
    local T0="$SECONDS"
    while ! grep -qE "$WHAT" "$FILE" &&  [[ "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done

}

function _on_horeka () {
    hostname | grep -q -E "hkn[0-9]{4}.localdomain"
}
