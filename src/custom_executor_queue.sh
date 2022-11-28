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

function submit_to_custom_executor_queue() {
    local JOBSCRIPT=$1
    cp "$JOBSCRIPT" "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/TODO
    local JOB TODO
    TODO="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/TODO
    JOB="$(basename "$JOBSCRIPT")"

    _log "Submitted $TODO/$JOB to custom executor queue"
}

function custom_executor_queue_is_alive () {
    ps --pid $CUSTOM_EXECUTOR_QUEUE_JOBID > /dev/null
}

function stop_custom_executor_queue () {
    kill $CUSTOM_EXECUTOR_QUEUE_JOBID
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

function emergency_stop () {
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
    exit 0
}


function cleanup_custom_executor_queue_workspace() {
    stop_custom_executor_queue
    rm -r "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"
}

function _custom_executor_queue () {
    _log "Starting custom executor queue."
    local SUBMITTEDPID
    local TODO="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/TODO
    local WORKING="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/WORKING
    local DONE="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/DONE
    local OUTPUT="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/OUTPUT
    local LOGS="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/LOGS
    trap emergency_stop SIGTERM SIGUSR1
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
             trap "echo \"$(date)\" \"$(hostname)\" \"$BNAME was terminated.\" >> \"$LOGS/$BNAME.log\"; exit 0" SIGTERM
             set +o pipefail
             set +o errexit
             set +o nounset
             "$WORKING/$BNAME" &> "$OUTPUT/$BNAME.out"
             echo $? > "$OUTPUT/$BNAME.exitcode"
             set -o nounset
             set -o errexit
             set -o pipefail
             mv "$WORKING/$BNAME" "$DONE"
             echo "$(date)" "$(hostname)" "$BNAME has ended" >> "$LOGS/$BNAME.log"
            ) &
            SUBMITTEDPID=$!
            _log "$BNAME (PID=$SUBMITTEDPID) launched."
            echo "$SUBMITTEDPID" >> "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS"
        done
        shopt -u nullglob
        for _ in  $(seq "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME")
        do
            sleep 1
        done
    done

    wait
}

function _create_directories(){
    for SUBDIR in TODO WORKING DONE OUTPUT LOGS
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
