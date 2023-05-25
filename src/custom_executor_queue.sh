#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

function start_custom_executor_queue () {
    if [[ $# -gt 2 ]]
    then
        echo "Too many arguments to 'start_custom_executor_queue', exiting" >&2
        return 1
    fi
    declare -i CUSTOM_EXECUTOR_QUEUE_CYCLETIME
    # In seconds
    CUSTOM_EXECUTOR_QUEUE_CYCLETIME=3 # DEBUG
    CUSTOM_EXECUTOR_QUEUE_WORKSPACE="$1"
    if [ "$#" -eq 2 ]
    then
        CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC="$2"
    else
        set +o nounset
        if [ -z "$CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC" ]
        then
        CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC=100 # seconds
        fi
        set -o nounset
    fi

    _create_directories
    CUSTOM_EXECUTOR_QUEUE_LOGFILE="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/log.txt
    touch "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"
    CUSTOM_EXECUTOR_QUEUE_LAST_ACTIVITY="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/last_activity
    CUSTOM_EXECUTOR_QUEUE_SCRID_FILE="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/scridcount
    echo 1 > "$CUSTOM_EXECUTOR_QUEUE_SCRID_FILE"

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

function _todoname(){
    local JOB SCRID
    JOB=$1
    SCRID=$2
    local TODO="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/TODO
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "${TODO}/${BNAME}-${SCRID}"
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

function _pidfname(){
    JOB=$1
    local PIDS="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/PIDS
    local BNAME
    BNAME="$(basename "$JOB")"
    echo "$PIDS/$BNAME"
}


function submit_to_custom_executor_queue() {

    if [ "$#" -lt 2 ] || [[ "$2" =~ --with-env ]]
    then
        echo "Usage: $0 script jobtag [--with-env]"
        exit 95
    fi
    if ! custom_executor_queue_is_alive
    then
        echo -n "ERROR: Custom executor queue process " >&2
        echo    "$CUSTOM_EXECUTOR_QUEUE_PID not running!" >&2
	echo -n "       or slurm job terminated." >&2
        return 1
    fi
    local ORIG_JOBSCRIPT="$1"
    local JOBTAG="$2"
    _log "Received request to execute $ORIG_JOBSCRIPT under $JOBTAG"

    local SCRID
    SCRID=$(cat "$CUSTOM_EXECUTOR_QUEUE_SCRID_FILE")
    while ! (set -o noclobber; echo > "$(_todoname "$ORIG_JOBSCRIPT" "$SCRID")")
    do
        echo "increasing scrid: $SCRID" >&2
        SCRID=$((SCRID+1))
    done
    # NOTE: This is not race-free at all.
    echo $((SCRID+1)) > "$CUSTOM_EXECUTOR_QUEUE_SCRID_FILE"
    local TODONAME
    TODONAME="$(_todoname "$ORIG_JOBSCRIPT" "$SCRID")"
    echo "$TODONAME"
    cp "$ORIG_JOBSCRIPT" "$TODONAME"
    chmod +x "$TODONAME"

    local JOBSCRIPT
    JOBSCRIPT="$TODONAME"
    local BNAME
    BNAME="$(basename "$JOBSCRIPT")"
    echo "$BNAME" >> "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/$JOBTAG"

    local LOCATIONFNAME
    LOCATIONFNAME="$(_locationfname "$JOBSCRIPT")"
    pwd > "$LOCATIONFNAME"

    local ENVFNAME
    ENVFNAME="$(_envfname "$JOBSCRIPT")"
    touch "$ENVFNAME"
    if [[ "$#" -eq 3 ]] && [[ "$3" == "--with-env" ]]
    then
        declare -p > "$ENVFNAME"
    fi

    _log "Submitted $TODONAME to custom executor queue"
}


function submit_to_custom_executor_queue_and_wait() {
    TODONAME="$(submit_to_custom_executor_queue "$@")" || exit "$SYSTEM_FAILURE_EXIT_CODE"

    DONENAME="$(_donename "$TODONAME")"
    OUTPUTNAME="$(_outputname "$TODONAME")"
    EXITVALUEFNAME="$(_exitvaluefname "$TODONAME")"
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

    shopt -s nullglob
    for PIDFILE in "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS/*
    do
        read -r CHILD_PID < "$PIDFILE"
        if ps --pid "$CHILD_PID" > /dev/null
        then
            _log "Sending SIGTERM to process $CHILD_PID"
            kill -TERM "$CHILD_PID"
        else
            _log "Process $CHILD_PID has already completed."
        fi
    done
    shopt -u nullglob
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
    local CANC_REQS="${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/CANC_REQS
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
                 PIDFILE=$(_pidfname "$JOB")
                 echo "$BASHPID" > "$PIDFILE"
                 # shellcheck disable=SC2064
                 set +o pipefail
                 set +o errexit
                 set +o nounset
                 # cd "$(cat "$LOCATIONFNAME")" # DEBUG: This might cause problems.
                 # shellcheck disable=SC1090
                 source <(purge_variables < "$ENVFNAME")
                 "$WNAME" &> "$OUTPUTNAME" &
                 RUNNINGPID=$!
                 trap 'kill '"$RUNNINGPID"'; \
                       _log "'"$BNAME"' was terminated."; \
                       rm '"$PIDFILE"'; \
                       exit 0' SIGTERM SIGUSR1
                 wait "$RUNNINGPID"
                 echo $? > "$EXITVALUEFNAME"
                 rm "$PIDFILE"
                 set -o nounset
                 set -o errexit
                 set -o pipefail
                 DONENAME="$(_donename "$JOB")"
                 mv "$WNAME" "$DONENAME"
                 _log "$BNAME has ended."
                ) &
                SUBMITTEDPID=$!
                _log "$BNAME (PID=$SUBMITTEDPID) launched."
            else
                _log "Waiting on $JOB, $BNAME still in progess..."
            fi
        done
        for CANC_REQ in "$CANC_REQS"/*
        do
            _log "Requested cancellation of $CANC_REQ"
            cancel_job_group "$(basename "$CANC_REQ")"
            rm "$CANC_REQ"
        done
        shopt -u nullglob
        if [ "$(jobs -rp)" ]
        then
          date +%s > "$CUSTOM_EXECUTOR_QUEUE_LAST_ACTIVITY"
        else
          if [[ "$(idle_time)" -ge "$CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC" ]]
          then
                 _log "Idle time $CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC reached, exiting."
                 break
          else
              _log "Idling for $(idle_time)/$CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC"
          fi
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
    for SUBDIR in TODO WORKING DONE OUTPUT ORIGINAL_LOCATIONS ENVS PIDS CANC_REQS
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

function idle_time(){
     TIME_NOW="$(date +%s)"
     TIME_LAST_ACTIVITY="$(cat "$CUSTOM_EXECUTOR_QUEUE_LAST_ACTIVITY")"
     echo "$((TIME_NOW-TIME_LAST_ACTIVITY))"

}

function cancel_job_group() {
    JOBTAG="$1"
    local SUBJOBPID
    #for BNAME in $(cat "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/$JOBTAG")
    while read -r BNAME
    do
        if [ -f "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$BNAME" ]
        then
            read -r SUBJOBPID < "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$BNAME"
            _log "Killing $BNAME with $SUBJOBPID"
            kill -s SIGTERM "$SUBJOBPID"
        fi
    done < "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/$JOBTAG"

}

function request_cancel_job_group() {
    JOBTAG=$1
    touch "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/CANC_REQS/$JOBTAG"

}

function at_least_half_idle_time_is_left(){
    [ $((2*$(idle_time))) -lt "$CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC"  ]
}
