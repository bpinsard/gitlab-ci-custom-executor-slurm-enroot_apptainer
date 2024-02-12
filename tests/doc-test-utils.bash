#!/usr/bin/env bash

function grep_between {

    START_STRING="$1"
    END_STRING="$2"

    ARGS=("$@")
    FILE="${ARGS[-1]}"

    START_LINENO="$(grep -n "$START_STRING" "$FILE" | head -n 1 | cut -d: -f1)"
    NLINES="$(grep -n "$END_STRING" <(tail -n +$((START_LINENO+1)) "$FILE") | head -n 1 | cut -d: -f1)"

    NARGS=$(($#-1-2))

    grep "${@:3:$NARGS}" <( tail  -n +"$START_LINENO" "$FILE" | head -n "$((NLINES+1))")

}
