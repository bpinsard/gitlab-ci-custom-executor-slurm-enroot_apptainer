#!/usr/bin/env bash

function load_mocks(){
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PATH"
}


function json_validate () {
    python3 -c 'import json,sys;json.load(sys.stdin)' || ( echo "JSON validation failed" && exit 1 )
}

function wait_until_file_exists() {
    local FILE="$1"
    local MAXDELAY="$2"
    local T0="$SECONDS"
    if [ "$#" -ne 2 ]; then echo "wrong number of arguments to ${FUNCNAME[0]}"; fi
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

function wait_until_file_contains() {
    local FILE="$1"
    local WHAT="$2"
    local MAXDELAY="$3"
    if [ "$#" -ne 3 ]; then echo "wrong number of arguments to ${FUNCNAME[0]}"; fi
    local T0="$SECONDS"
    while ! grep -qE "$WHAT" "$FILE" &&  [[ "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done
    if ! grep -qE "$WHAT" "$FILE"
    then
        echo "Error: Waited too long ($MAXDELAY) for $FILE to contain \"$WHAT\"."
        return 124
    fi


}

function scontrol_pre_wait_job_with_deadline() {
    # scontrol tends to fail
    local JOB_ID
    JOB_ID=$1
    local MAXDELAY=$2
    if [ "$#" -ne 2 ]; then echo "wrong number of arguments to ${FUNCNAME[0]}"; fi
    local T0="$SECONDS"
    while ! scontrol wait_job "$JOB_ID" &&  [[ "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
	echo "squeue output:"
        squeue
        sleep 3
    done
    if ! scontrol wait_job "$JOB_ID"
    then
        echo "ERROR: Waited too long ($MAXDELAY) for $JOB_ID to become available."
        return 124
    fi

}

function try_to_remove_dir(){
    local DIR_TO_REMOVE=$1

    local TRIES
    TRIES=0
    while ! rm -r "$DIR_TO_REMOVE"
    do
        if [ "$TRIES" -eq 5 ] # Max tries 5
        then
            return 1
        fi
        echo "# Retrying in 5 sec failed removal of $DIR_TO_REMOVE " >&3
        sleep 5
        TRIES=$((TRIES+1))

    done
}
