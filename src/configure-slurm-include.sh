#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/include.sh
source "$SRC/include.sh"

function export_custom_env_var_into_var_if_defined() {
    # If a variable called `CUSTOM_ENV_$VAR` is defined
    # in che current environment,
    # then export its value as VAR.

    local VAR="$1"

    set +o nounset
    eval 'if [[ ! -z "$CUSTOM_ENV_'"$VAR"'" ]];
          then
            export '"$VAR"'="$CUSTOM_ENV_'"$VAR"'";
          fi; '
    set -o nounset

}

function export_all_custom_env_var_into_var_if_defined() {
    local SRC
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

    for VAR in $("$SRC"/slurm-utils/get-sbatch-input-env-list.sh)
    do
        export_custom_env_var_into_var_if_defined "$VAR"
    done
}


function wait_until_file_exists() {
    local FILE="$1"
    local MAXDELAY="$2"
    local T0="$SECONDS"
    if [ "$#" -ne 2 ]
    then 
	    echo "wrong number of arguments to ${FUNCNAME[0]}" >&2
	    exit 22
    fi
    while [[ ! -f "$FILE" && "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done
    if [[ !  -f "$FILE" ]]
    then
        echo "Error: Waited too long ($MAXDELAY) for $FILE to be created". >&2
        return 124
    fi

}

function check_custom_env_ci_ws_set(){
    set +o nounset
    if [[ -z "$CUSTOM_ENV_CI_WS" ]]
    then
        echo "ERROR: CUSTOM_ENV_CI_WS variable not defined." >&2
        echo "       Please define the CI_WS variable in your gitlab CI/CD setup (See README)." >&2

        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi
    set -o nounset
}

function check_or_set_custom_env_command_sbatch(){
    local JOBSLURM="$1"
    set +o nounset
    if [[ -z "$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH" ]]
    then
        local SRC
        SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
        echo "Warning: CUSTOM_ENV_COMMAND_OPTIONS_SBATCH not set, working with default options" >&2
        echo "         See header of $JOBSLURM" >&2
        grep '#SBATCH' "$JOBSLURM" >&2
        export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH=""
    fi
    set -o nounset
}


function get_sbatch_command(){
    local SRC
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
    local WORKSPACE="$1"
    local CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="$2"
    local SCRIPT="$3"

    # We DO want to split words here
    # shellcheck disable=SC2206
    COMMAND=(sbatch $CUSTOM_ENV_COMMAND_OPTIONS_SBATCH
             --propagate=NONE
             --parsable
        	 --signal=B:USR1@15 # SIGUSR1 15 seconds before the end of the job.
    	 )

    # DEBUG OPTIONS

    set +o nounset
    if [[ -z "$CUSTOM_ENV_CE_DEBUG" ]]
    then
        COMMAND+=( --input=/dev/null
                   --output=/dev/null
                   --error=/dev/null
    	      )
    else
        COMMAND+=( --input=/dev/null
                   --output=/home/hk-project-scs/%u/cetest%J.out
                   --error=/home/hk-project-scs/%u/cetest%J.err
        )
    fi
    set -o nounset

    # FINAL SBATCH INVOCATION
    COMMAND+=("$SCRIPT" "$WORKSPACE" "$SRC")

    echo "${COMMAND[@]}"

}

function check_for_forbidden_option(){
    ALL_OPTIONS="$1"
    FORBIDDEN_OPTION="$2"
    if [[ "$ALL_OPTIONS" =~ $FORBIDDEN_OPTION ]]
    then
        echo "Error: please do not use $FORBIDDEN_OPTION" >&2
        return 22
    fi
}

function check_string_has_no_forbidden_options(){
    ALL_OPTIONS="$1"
    for TOKEN in $(get_sbatch_command "WS" "" "")
    do
        if [[ "$TOKEN" =~ --[a-z_\-]+ ]]
        then

            check_for_forbidden_option \
                "$ALL_OPTIONS" \
                "${BASH_REMATCH[0]}" || return 22
        fi
    done
}

function wait_for_job_to_be_ready(){
    local JOB_ID="$1"
    while ! scontrol wait_job "$JOB_ID" &> /dev/null
    do
        sleep 3
        if [ $((SECONDS % 20)) -lt 3 ]
        then
            STARTTIME="$(squeue --start --job "$JOB_ID" --format %S | tail -n 1)"
            echo "$(date) Expected start: $STARTTIME" >&2
        fi
    done
}


function print_slurm_environment(){

    set +o nounset
    for VAR in $("$SRC"/slurm-utils/get-sbatch-input-env-list.sh)
    do
       echo "$VAR=${!VAR}"
    done
    echo COMMAND_OPTIONS_SBATCH="$CUSTOM_ENV_COMMAND_OPTIONS_SBATCH"
    set -o nounset

}

function find_available_workspace_name(){

    ROOT="$1"
    ROOTDIR="$(dirname "$ROOT")"
    if [[ ! -d "$ROOTDIR" ]]
    then
        echo "Not an existing directory: $ROOTDIR" >&2
        return 22
    fi

    N=0;
    while true
    do
       CANDIDATE="$ROOT$N"
       if [[ -d "$CANDIDATE" ]] || [[ -f "$CANDIDATE" ]]
       then
           N=$((N+1))
       else
           break
       fi
    done
    echo "$CANDIDATE"

}

function find_remaining_time_sec_in_allocation(){

    local WORKSPACE="$1"

    local JOBID
    JOBID="$(get_slurm_jobid "$WORKSPACE")"

    read -r STATE END_TIME < <(squeue -j "$JOBID"  --Format=State,EndTime 2> /dev/null| tail -n 1)

    if [[ "$STATE" == "RUNNING" ]]
    then
        NOW_UNIX="$(date +%s)"
        END_TIME_UNIX="$(date --date="$END_TIME" +%s)"
        echo $((END_TIME_UNIX - NOW_UNIX))
    else
        echo 0
    fi

}


function has_at_least_half_idle_time_left(){
    local WORKSPACE=$1

    (
        # shellcheck disable=SC1091
        source "$WORKSPACE/.env"
        # shellcheck source=./src/custom_executor_queue.sh
        source "$SRC/custom_executor_queue.sh"
        at_least_half_idle_time_is_left
    )
}


function allocation_is_compatible(){
    local SLURMENV=$1
    local JOB_TIME_SEC=$2
    local WORKSPACE=$3
    local ANC="Allocation not compatible: "
    # shellcheck disable=SC2015
    { [[ -f "$WORKSPACE/.env" ]] ||
          { echo "$ANC $WORKSPACE has no env" >&2 && return 1; } } &&
    { [[ -f "$WORKSPACE/slurmenv" ]] ||
          { echo "$ANC $WORKSPACE has no slurmenv" >&2 && return 1; } } &&
    { [[ $(diff "$SLURMENV" "$WORKSPACE/slurmenv" | wc -l ) -eq 0 ]] ||
          { echo "$ANC slurmenv is different for $WORKSPACE" >&2 && return 1; } } &&
    { has_at_least_half_idle_time_left "$WORKSPACE" ||
          { echo "$ANC not enough idle time left in $WORKSPACE" >&2 && return 1; } } &&
    { ! has_slurm_job_id "$WORKSPACE"  ||
    [ "$JOB_TIME_SEC" -lt "$(find_remaining_time_sec_in_allocation "$WORKSPACE")"  ] &&
        echo "Allocation Compatible: $WORKSPACE" >&2; } || {
        echo "$ANC $WORKSPACE has slurm job id but not enough time in the allocation" >&2 && return 1 ;
    }

}

function create_job_slurm(){

    local TEMPLATE="$1"
    local DEFAULT_PARTITION="$2"
    local OUTDIR="$3"

    mkdir -p "$OUTDIR"

    sed 's/%CUSTOM_ENV_DEFAULT_PARTITION%/'"$DEFAULT_PARTITION"'/' "$TEMPLATE"  \
        > "$OUTDIR/job.slurm"

    chmod +x "$OUTDIR/job.slurm"
    echo "$OUTDIR/job.slurm"

}
