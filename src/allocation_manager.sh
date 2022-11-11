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
    ALLOCATION_MANAGER_LOGFILE="$ALLOCATION_MANAGER_WORKSPACE"/log.txt
    ALLOCATION_MANAGER_JOBPIDS="$ALLOCATION_MANAGER_WORKSPACE"/pids.txt
    touch "$ALLOCATION_MANAGER_LOGFILE"
    touch "$ALLOCATION_MANAGER_JOBPIDS"

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
    kill $ALLOCATION_MANAGER_JOBID
    while allocation_manager_is_alive
    do
    sleep 1
    done
}


function list_all_child_pids() {
    # Note: this function should not be called in a subshell
    # or in a pipe
    # or 'jobs -p' would just return no jobs.
    jobs -p | sed -r 's/[+-]//;s/\s+/ /g' | cut -d' ' -f2
}

function emergency_stop () {
    _log "Stopping allocation manager..."
    while read -r CHILD_PID
    do
        if ps --pid "$CHILD_PID" > /dev/null
        then
            _log "Sending SIGTERM to process $CHILD_PID"
            kill -TERM "$CHILD_PID"
        else
            _log "Process $CHILD_PID has already completed."
        fi
    done < "$ALLOCATION_MANAGER_JOBPIDS"
    _log "Sent kill signal to all the jobs"
    exit 0
}


function cleanup_allocation_manager_workspace() {
    stop_allocation_manager
    rm -r "${ALLOCATION_MANAGER_WORKSPACE}"
}

function _allocation_manager () {
    _log "Starting allocation manager."
    local SUBMITTEDPID
    local TODO="${ALLOCATION_MANAGER_WORKSPACE}"/TODO
    local WORKING="${ALLOCATION_MANAGER_WORKSPACE}"/WORKING
    local DONE="${ALLOCATION_MANAGER_WORKSPACE}"/DONE
    local OUTPUT="${ALLOCATION_MANAGER_WORKSPACE}"/OUTPUT
    trap emergency_stop SIGTERM
    while true
    do
        shopt -s nullglob
        for JOB in "$TODO"/*
        do
            _log "Processing $JOB ..."
            local BNAME
            BNAME="$(basename "$JOB")"
            mv "$JOB" "$WORKING"/"$BNAME"
            (
             # shellcheck disable=SC2064
             trap "_log $BNAME was terminated. ; exit 0" SIGTERM
             "$WORKING"/"$BNAME" &> "$OUTPUT"/"$BNAME".out
             mv "$WORKING"/"$BNAME" "$DONE"
             _log "$BNAME has ended"
            ) &
            SUBMITTEDPID=$!
            _log "$BNAME (PID=$SUBMITTEDPID) launched."
            echo "$SUBMITTEDPID" >> "$ALLOCATION_MANAGER_JOBPIDS"
        done
        shopt -u nullglob
        for _ in  $(seq "$ALLOCATION_MANAGER_CYCLETIME")
        do
            sleep 1
        done
    done

    wait
}

function _create_directories(){
    for SUBDIR in TODO WORKING DONE OUTPUT
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
