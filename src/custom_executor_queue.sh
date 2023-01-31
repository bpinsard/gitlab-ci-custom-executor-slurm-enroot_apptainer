#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail


function start_custom_executor_queue () {
    if [[ $# -gt 1 ]]
    then
        echo "Too many arguments to 'start_custom_executor_queue', exiting" >&2
        return 1
    fi
    declare -i CUSTOM_EXECUTOR_QUEUE_CYCLETIME
    # In seconds
    CUSTOM_EXECUTOR_QUEUE_CYCLETIME=3 # DEBUG
    CUSTOM_EXECUTOR_QUEUE_WORKSPACE=$1
    _create_directories
    CUSTOM_EXECUTOR_QUEUE_LOGFILE="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/log.txt
    CUSTOM_EXECUTOR_QUEUE_JOBPIDS="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/pids.txt
    touch "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"
    touch "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS"

    _custom_executor_queue > /dev/null &
    CUSTOM_EXECUTOR_QUEUE_JOBID=$!

    # shellcheck disable=SC2086
    declare -p ${!CUSTOM_EXECUTOR_QUEUE*} > "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/.env
}

function _todoname() {

    JOB=$1
    local TODO="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/TODO
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "$TODO/$BNAME"

}

function _wname(){
    JOB=$1
    local WORKING="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/WORKING
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "$WORKING/$BNAME"
}

function _outputname(){
    JOB=$1
    local OUTPUT="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/OUTPUT
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "$OUTPUT/$BNAME.out"
}

function _exitvaluefname(){
    JOB=$1
    local OUTPUT="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/OUTPUT
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "$OUTPUT/$BNAME.exitcode"
}

function _donename(){
    JOB=$1
    local DONE="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/DONE
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "$DONE/$BNAME"
}

function _locationfname(){
    JOB=$1
    local ORIGINAL_LOCATIONS="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/ORIGINAL_LOCATIONS
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "$ORIGINAL_LOCATIONS/$BNAME"
}



function submit_to_custom_executor_queue() {
    local JOBSCRIPT=$1

    local BNAME
    BNAME="$(basename "$JOBSCRIPT")"
    if [ -f  "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/TODO/$BNAME" ]
    then
        return 45
    fi
    local TODONAME
    TODONAME="$(_todoname "$JOBSCRIPT")"
    cp "$JOBSCRIPT" "$TODONAME"
    local LOCATIONFNAME
    LOCATIONFNAME="$(_locationfname "$JOBSCRIPT")"
    pwd > "$LOCATIONFNAME"
    _log "Submitted $TODONAME to custom executor queue"
}


function submit_to_custom_executor_queue_and_wait() {
    local JOB=$1
    submit_to_custom_executor_queue "$JOB"
    DONENAME="$(_donename "$JOB")"
    OUTPUTNAME="$(_outputname "$JOB")"
    EXITVALUEFNAME="$(_exitvaluefname "$JOB")"
    while [ ! -f "$DONENAME" ] && [ ! -f  "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/terminated" ]
    do
        sleep 1
    done
    if [ ! -f "$DONENAME" ] && [ -f  "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/terminated" ]
    then
    echo "Abnormal termination of script, exiting."
    exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    TIME="$(date +"%s")"
    mv "$DONENAME" "$DONENAME"-"$TIME"
    cat "$OUTPUTNAME"
    read -r EXITVALUE < "$EXITVALUEFNAME"
    exit "$EXITVALUE"

}


function custom_executor_queue_is_alive () {
    ps --pid "$CUSTOM_EXECUTOR_QUEUE_JOBID" > /dev/null
}

function stop_custom_executor_queue () {
    stop_all
    kill "$CUSTOM_EXECUTOR_QUEUE_JOBID"
    while custom_executor_queue_is_alive
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

function stop_all () {
    _log "Stopping custom executor queue..."
    while read -r CHILD_PID
    do
        if ps --pid "$CHILD_PID" > /dev/null
        then
            _log "Sending SIGTERM to process $CHILD_PID"
            kill -TERM "$CHILD_PID"
        else
            _log "Process $CHILD_PID has already completed."
        fi
    done < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS"
    _log "Sent kill signal to all the jobs"
}

function emergency_stop () {
    stop_all
    exit 0
}

function cleanup_custom_executor_queue_workspace() {
    stop_custom_executor_queue
    rm -r "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"
}


function _custom_executor_queue () {
    trap emergency_stop SIGTERM SIGUSR1
    # shellcheck disable=SC2064
    trap "touch $CUSTOM_EXECUTOR_QUEUE_WORKSPACE/terminated;" EXIT

    _log "Starting custom executor queue."
    local SUBMITTEDPID
    local TODO="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/TODO
    while true
    do
        shopt -s nullglob
        for JOB in "$TODO"/*
        do
            local BNAME
            BNAME="$(basename "$JOB")"
            local WNAME
            WNAME="$(_wname "$JOB")"
            local LOCATIONFNAME
            LOCATIONFNAME="$(_locationfname "$JOB")"
            if [ ! -f "$WNAME" ]
            then
                _log "Processing $JOB ..."
                mv "$JOB" "$WNAME"
                OUTPUTNAME="$(_outputname "$JOB")"
                EXITVALUEFNAME="$(_exitvaluefname "$JOB")"
                (
                 # shellcheck disable=SC2064
                 set +o pipefail
                 set +o errexit
                 set +o nounset
                 (
                  cd "$(cat "$LOCATIONFNAME")"
                  "$WNAME" &> "$OUTPUTNAME"
                  echo $? > "$EXITVALUEFNAME" ) &
                 RUNNINGPID=$!
                 set -o nounset
                 set -o errexit
                 set -o pipefail
                 trap 'kill '"$RUNNINGPID"'; \
                       _log "'"$BNAME"' was terminated."; \
                       exit 0' SIGTERM
                 wait $RUNNINGPID
                 DONENAME="$(_donename "$JOB")"
                 mv "$WNAME" "$DONENAME"
                 _log "$BNAME has ended."
                ) &
                SUBMITTEDPID=$!
                _log "$BNAME (PID=$SUBMITTEDPID) launched."
                echo "$SUBMITTEDPID" >> "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS"
            else
                _log "Waiting on $JOB, $BNAME still in progess..."
            fi
        done
        shopt -u nullglob
        local CYCLESTART="$SECONDS"
        local CYCLEEND="$((CYCLESTART + CUSTOM_EXECUTOR_QUEUE_CYCLETIME))"
        while [[ "$SECONDS" -lt "$CYCLEEND" ]]
        do
            sleep 1
        done
    done

    wait
}

function _create_directories(){
    for SUBDIR in TODO WORKING DONE OUTPUT ORIGINAL_LOCATIONS
    do
        mkdir -p "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/$SUBDIR
    done
}


function _current_time(){
    echo $SECONDS
}

function _log() {
	echo "$(date)" "$(hostname)" "$@" >> "${CUSTOM_EXECUTOR_QUEUE_LOGFILE}"
}
