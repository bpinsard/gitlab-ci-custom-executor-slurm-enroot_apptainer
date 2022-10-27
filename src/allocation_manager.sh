#!/usr/bin/env bash

function start_allocation_manager () {
    ALLOCATION_MANAGER_MAX_RUNTIME=$1
    ALLOCATION_MANAGER_WORKSPACE=$2
    _create_directories
    ALLOCATION_MANAGER_LOGFILE="${ALLOCATION_MANAGER_WORKSPACE}"/log.txt
    touch "${ALLOCATION_MANAGER_LOGFILE}"

    allocation_manager "${ALLOCATION_MANAGER_MAX_RUNTIME}" > /dev/null &
    ALLOCATION_MANAGER_JOBID=$!
    declare -p ${!ALLOCATION_MANAGER*} > "${ALLOCATION_MANAGER_WORKSPACE}"/.env
}

function _create_directories(){
    for SUBDIR in todo done
    do
        mkdir -p "${ALLOCATION_MANAGER_WORKSPACE}"/$SUBDIR
    done
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

function allocation_manager () {
    local START_TIME=$(_current_time)
    local END_TIME=$((START_TIME + ALLOCATION_MANAGER_MAX_RUNTIME))
    local TODO="${ALLOCATION_MANAGER_WORKSPACE}"/todo
    local DONE="${ALLOCATION_MANAGER_WORKSPACE}"/done
    while [[ $(_current_time) -lt $END_TIME ]]
    do
        for JOB in $(ls $TODO )
        do
            _log "Processing $TODO/$JOB ..."
            $TODO/$JOB
            mv $TODO/$JOB $DONE
            _log "$TODO/$JOB has ended"
        done
        sleep 1 # TODO: lengthen interval
    done
}

function _current_time(){
    echo $SECONDS
}

function submit_to_allocation_manager() {
    local JOBSCRIPT=$1
    cp $JOBSCRIPT "${ALLOCATION_MANAGER_WORKSPACE}"/todo

    _log "Submitted $TODO/$JOB to allocation manager"
}

function _log() {
    echo $(date) $@ >> ${ALLOCATION_MANAGER_LOGFILE}
}
