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
    CUSTOM_EXECUTOR_QUEUE_WORKSPACE="$1"
    _create_directories
    CUSTOM_EXECUTOR_QUEUE_LOGFILE="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/log.txt
    CUSTOM_EXECUTOR_QUEUE_JOBPIDS="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/pids.txt
    touch "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"
    touch "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS"
    CUSTOM_EXECUTOR_QUEUE_LAST_ACTIVITY="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/last_activity

    _custom_executor_queue > /dev/null &
    CUSTOM_EXECUTOR_QUEUE_PID=$!
    CUSTOM_EXECUTOR_QUEUE_HOSTNAME=$(hostname)

    set +o nounset
    if [ -n "$SLURM_JOB_ID" ]
    then
        # shellcheck disable=SC2034
        CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID="$SLURM_JOB_ID"
    fi
    set -o nounset
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

function _envfname(){
    JOB=$1
    local ENVS="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/ENVS
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "$ENVS/$BNAME.env"
}


function submit_to_custom_executor_queue() {

    if ! custom_executor_queue_is_alive
    then
        echo "ERROR: Custom executor queue process $CUSTOM_EXECUTOR_QUEUE_PID not running!"
        return 1
    fi
    local JOBSCRIPT=$1
    local BNAME
    BNAME="$(basename "$JOBSCRIPT")"
    if [ -f  "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/TODO/$BNAME" ]
    then
        return 22
    fi

    local TODONAME
    TODONAME="$(_todoname "$JOBSCRIPT")"
    cp "$JOBSCRIPT" "$TODONAME"

    local LOCATIONFNAME
    LOCATIONFNAME="$(_locationfname "$JOBSCRIPT")"
    pwd > "$LOCATIONFNAME"

    local ENVFNAME
    ENVFNAME="$(_envfname "$JOBSCRIPT")"
    touch "$ENVFNAME"
    if [[ "$#" -eq 2 ]] && [[ "$2" == "--with-env" ]]
    then
        declare -p > "$ENVFNAME"
    fi

    _log "Submitted $TODONAME to custom executor queue"
}


function submit_to_custom_executor_queue_and_wait() {
    submit_to_custom_executor_queue "$@" || exit "$SYSTEM_FAILURE_EXIT_CODE"

    local JOB=$1
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
    return "$EXITVALUE"

}


function custom_executor_queue_is_alive () {
    if [[ "$CUSTOM_EXECUTOR_QUEUE_HOSTNAME" == "$(hostname)" ]]
    then
        ps --pid "$CUSTOM_EXECUTOR_QUEUE_PID" &> /dev/null
    else
        scontrol wait_job "$CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID" &> /dev/null
    fi
}

function stop_custom_executor_queue () {
    stop_all
    kill "$CUSTOM_EXECUTOR_QUEUE_PID"
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
    date +%s > "$CUSTOM_EXECUTOR_QUEUE_LAST_ACTIVITY"

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
            local ENVFNAME
            ENVFNAME="$(_envfname "$JOB")"
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
                  # shellcheck disable=SC1090

                  source <(purge_variables < "$ENVFNAME")
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
        if [ "$(jobs)" ]
        then
          date +%s > "$CUSTOM_EXECUTOR_QUEUE_LAST_ACTIVITY"
        fi
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
    for SUBDIR in TODO WORKING DONE OUTPUT ORIGINAL_LOCATIONS ENVS
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

function purge_variables() {

     # this might be extremely dumb
     SCRIPT=$(mktemp .scriptXXXX)

     declare -p | \
     grep -E "declare -[aAilntux]*r"  | \
     cut -d= -f1 | \
     cut -d' ' -f3 | \
     while read -r VARNAME
     do
         echo '/[[:blank:]]'"$VARNAME"'=/d;' >> "$SCRIPT"
         echo '/[[:blank:]]'"$VARNAME"'[[:blank:]]*$/d;' >> "$SCRIPT"
     done

     PATTERN_BLACKLIST=('SLURM.*'
                        'BASH.*'
                        'BATS.*'
                        'FUNCNAME' # known to cause problems
                        'GROUPS') # known to cause problems

     for PATTERN in "${PATTERN_BLACKLIST[@]}"
     do
         echo '/[[:blank:]]'"$PATTERN"'=/d;' >> "$SCRIPT"
         echo '/[[:blank:]]'"$PATTERN"'[[:blank:]]*$/d;' >> "$SCRIPT"
     done
     sed --posix -f "$SCRIPT"
     rm "$SCRIPT"


}
