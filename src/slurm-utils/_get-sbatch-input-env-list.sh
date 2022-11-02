#!/usr/bin/env bash
# This script parses the man page of sbatch
# to get all the names of the environment variables
# that affect the execution.
# Ideally to be executed with
# ssh <horeka-host> bash < this-script.sh


# These

function get_line_from_content() {
    CONTENT=$1
    man sbatch | grep -n "$CONTENT" | cut -d: -f1
}

function get_relevant_lines_from_sbatch_manual() {
    local START
    local END

    START=$(get_line_from_content "INPUT ENVIRONMENT VARIABLES")
    END=$(get_line_from_content "OUTPUT ENVIRONMENT VARIABLES")

    man sbatch | head -n $((END-1)) | tail -n +$((START+1)) | grep -E '^\s+(SBATCH|SLURM)'

}


function sanitize_whitespace() {
   # To be used in a pipe
   # Converts all groups of whitespaces to a single SPC
   # Removes also leading whitespace
   sed -E 's/\s+/ /g' | sed -E 's/\s+//'
}


function get_first_word() {
   # To be used in a pipe
   cut -d' ' -f1
}

function get_additional_spellings() {
  # To be used in a pipe
  grep 'or SLURM' | cut -d' ' -f4
}


function remove_equals_at_end() {
    # In some cases, an '=SOMETHING' is appended
    sed 's/=.*//'

}

function get_all_env_var_names() {

get_relevant_lines_from_sbatch_manual | sanitize_whitespace | get_first_word | remove_equals_at_end
get_relevant_lines_from_sbatch_manual | sanitize_whitespace | get_additional_spellings | remove_equals_at_end

}

function on_horeka () {
    hostname | grep -E "hkn[0-9]{4}.localdomain"
}

declare -a INPUT_VARIABLES

if [[ ! $(on_horeka) ]]
then
  INPUT_VARIABLES=(
    SBATCH_ACCOUNT
    SBATCH_ACCTG_FREQ
    SBATCH_ARRAY_INX
    SBATCH_BATCH
    SBATCH_CLUSTERS
    SBATCH_CONSTRAINT
    SBATCH_CONTAINER
    SBATCH_CORE_SPEC
    SBATCH_CPUS_PER_GPU
    SBATCH_DEBUG
    SBATCH_DELAY_BOOT
    SBATCH_DISTRIBUTION
    SBATCH_EXCLUSIVE
    SBATCH_EXPORT
    SBATCH_GET_USER_ENV
    SBATCH_GPU_BIND
    SBATCH_GPU_FREQ
    SBATCH_GPUS
    SBATCH_GPUS_PER_NODE
    SBATCH_GPUS_PER_TASK
    SBATCH_GRES
    SBATCH_GRES_FLAGS
    SBATCH_HINT
    SBATCH_IGNORE_PBS
    SBATCH_JOB_NAME
    SBATCH_MEM_BIND
    SBATCH_MEM_PER_CPU
    SBATCH_MEM_PER_GPU
    SBATCH_MEM_PER_NODE
    SBATCH_NETWORK
    SBATCH_NO_KILL
    SBATCH_NO_REQUEUE
    SBATCH_OPEN_MODE
    SBATCH_OVERCOMMIT
    SBATCH_PARTITION
    SBATCH_POWER
    SBATCH_PROFILE
    SBATCH_QOS
    SBATCH_REQ_SWITCH
    SBATCH_REQUEUE
    SBATCH_RESERVATION
    SBATCH_SIGNAL
    SBATCH_SPREAD_JOB
    SBATCH_THREAD_SPEC
    SBATCH_THREADS_PER_CORE
    SBATCH_TIMELIMIT
    SBATCH_USE_MIN_NODES
    SBATCH_WAIT
    SBATCH_WAIT_ALL_NODES
    SBATCH_WAIT4SWITCH
    SBATCH_WCKEY
    SLURM_CONF
    SLURM_EXIT_ERROR
    SLURM_STEP_KILLED_MSG_NODE_ID
  )
else
  #shellcheck disable=SC2162
  read -a INPUT_VARIABLES <  <(get_all_env_var_names)
fi

echo "${INPUT_VARIABLES[@]}"
