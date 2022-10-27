#!/usr/bin/env bash

function start_allocation_manager () {
    declare -i ALLOCATION_MANAGER_MAX_RUNTIME ALLOCATION_MANAGER_CYCLETIME
    ALLOCATION_MANAGER_MAX_RUNTIME=$1
    ALLOCATION_MANAGER_CYCLETIME=$2
    ALLOCATION_MANAGER_WORKSPACE=$3
    _create_directories
    ALLOCATION_MANAGER_LOGFILE="${ALLOCATION_MANAGER_WORKSPACE}"/log.txt
    touch "${ALLOCATION_MANAGER_LOGFILE}"

    _allocation_manager "${ALLOCATION_MANAGER_MAX_RUNTIME}" > /dev/null &
    ALLOCATION_MANAGER_JOBID=$!
    declare -p ${!ALLOCATION_MANAGER*} > "${ALLOCATION_MANAGER_WORKSPACE}"/.env
}

function submit_to_allocation_manager() {
    local JOBSCRIPT=$1
    cp "$JOBSCRIPT" "${ALLOCATION_MANAGER_WORKSPACE}"/TODO

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

function cleanup_allocation_manager_workspace() {
    rm -r "${ALLOCATION_MANAGER_WORKSPACE}"
    stop_allocation_manager
}

function _allocation_manager () {
    local START_TIME
    START_TIME=$(_current_time)
    local END_TIME=$((START_TIME + ALLOCATION_MANAGER_MAX_RUNTIME))
    local TODO="${ALLOCATION_MANAGER_WORKSPACE}"/TODO
    local DONE="${ALLOCATION_MANAGER_WORKSPACE}"/DONE
    shopt -s nullglob
    while [[ $(_current_time) -lt $END_TIME ]]
    do
        for JOB in "$TODO"/*
        do
            _log "Processing $JOB ..."
            "$JOB"
            mv "$JOB" "$DONE"
            _log "$JOB" "has ended"
        done
        sleep "$ALLOCATION_MANAGER_CYCLETIME"
    done
    shopt -u nullglob
}

function _create_directories(){
    for SUBDIR in TODO DONE
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
