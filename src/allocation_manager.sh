#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail


function start_allocation_manager () {
    if [[ $# -gt 1 ]]
    then
        echo "Too many arguments to 'start_allocation_manager', exiting" >&2
        return 1
    fi
    declare -i ALLOCATION_MANAGER_CYCLETIME
    # In seconds
    ALLOCATION_MANAGER_CYCLETIME=3 # DEBUG
    ALLOCATION_MANAGER_WORKSPACE=$1
    _create_directories
    ALLOCATION_MANAGER_LOGFILE="${ALLOCATION_MANAGER_WORKSPACE}"/log.txt
    touch "${ALLOCATION_MANAGER_LOGFILE}"

    _allocation_manager > /dev/null &
    ALLOCATION_MANAGER_JOBID=$!

    # shellcheck disable=SC2086
    declare -p ${!ALLOCATION_MANAGER*} > "${ALLOCATION_MANAGER_WORKSPACE}"/.env
}

function submit_to_allocation_manager() {
    local JOBSCRIPT=$1
    cp "$JOBSCRIPT" "${ALLOCATION_MANAGER_WORKSPACE}"/TODO
    local JOB TODO
    TODO="${ALLOCATION_MANAGER_WORKSPACE}"/TODO
    JOB="$(basename "$JOBSCRIPT")"

    _log "Submitted $TODO/$JOB to allocation manager"
}

function allocation_manager_is_alive () {
    ps --pid $ALLOCATION_MANAGER_JOBID > /dev/null
}

function stop_allocation_manager () {
    # bs_log "Allocation manager stopped." # DEBUG
    kill $ALLOCATION_MANAGER_JOBID
    while allocation_manager_is_alive
    do
    sleep 1
    done
}

function emergency_stop () {
    date > /tmp/diocane # DEBUG
    _log "Stopping allocation manager..."
    exit 0
}


function cleanup_allocation_manager_workspace() {
    stop_allocation_manager
    rm -r "${ALLOCATION_MANAGER_WORKSPACE}"
}

function _allocation_manager () {
    _log "Starting allocation manager."
    local TODO="${ALLOCATION_MANAGER_WORKSPACE}"/TODO
    local DONE="${ALLOCATION_MANAGER_WORKSPACE}"/DONE
    local OUTPUT="${ALLOCATION_MANAGER_WORKSPACE}"/OUTPUT
    trap emergency_stop SIGINT
    shopt -s nullglob
    while true
    do
        for JOB in "$TODO"/*
        do
            _log "Processing $JOB ..."
            "$JOB" &> "$OUTPUT"/"$(basename "$JOB")".out
            mv "$JOB" "$DONE"
            _log "$JOB" "has ended"
        done
        sleep "$ALLOCATION_MANAGER_CYCLETIME"
    done
    shopt -u nullglob
}

function _create_directories(){
    for SUBDIR in TODO DONE OUTPUT
    do
        mkdir -p "${ALLOCATION_MANAGER_WORKSPACE}"/$SUBDIR
    done
}


function _current_time(){
    echo $SECONDS
}

function _log() {
    echo "$(date)" "$@" >> "${ALLOCATION_MANAGER_LOGFILE}"
}
