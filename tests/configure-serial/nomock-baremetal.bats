#!/usr/bin/env bash

function _on_horeka() {
   hostname | grep -q -E "hkn[0-9]{4}.localdomain"
}

function setup(){

    _on_horeka || skip

    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    export SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/$(mktemp -d configure-testXXXXXXX)"
    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    cat << EOF > get_jobid.py
import sys, json
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_SLURM_JOB_ID"])
EOF


    echo "Test setup phase completed."

    # shellcheck disable=SC2030
    CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_BUILDS_DIR
    mkdir -p "$CUSTOM_ENV_CI_BUILDS_DIR" # This should not be needed

    CEQ_ENV="$CUSTOM_ENV_CI_BUILDS_DIR/cews/.env"

}

function teardown() {
    if _on_horeka
    then
      echo scancel "$JOB_ID"
      scancel "$JOB_ID"
      echo rm -r "$TEST_PLAYGROUND"
      rm -r "$TEST_PLAYGROUND"
    fi
}

function wait_until_file_exists() {
    local FILE="$1"
    local MAXDELAY="$2"
    local T0="$SECONDS"
    while [[ ! -f "$FILE" && "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done

}


@test "configure launches custom executor queue in slurm job - no container" {

    ############################################
    # STARTING CUSTOM EXECUTOR QUEUE IN SLURM JOB #
    ############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 1 -n 1"
    JOB_ID=$("$SRC"/configure-slurm.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
	echo "squeue output:"
        squeue
        sleep 3
    done

    scontrol wait_job "$JOB_ID"

    wait_until_file_exists "$CEQ_ENV" 30

    assert [ -f "$CEQ_ENV" ]

}


@test "configure launches custom executor queue in slurm job - no container - submission" {


    ###############################################
    # STARTING CUSTOM EXECUTOR QUEUE IN SLURM JOB #
    ###############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 1 -n 1"
    JOB_ID=$("$SRC"/configure-slurm.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
	echo "squeue output:"
        squeue
        sleep 3
    done

    scontrol wait_job "$JOB_ID"

    wait_until_file_exists "$CEQ_ENV" 30

    #######################################
    # SUBMITTING TO CUSTOM EXECUTOR QUEUE #
    #######################################

    # shellcheck disable=SC1090
    source "$CEQ_ENV"
    # shellcheck disable=SC1091
    source "$SRC"/custom_executor_queue.sh

    cat << EOF > job.sh
#!/usr/bin/env bash
echo "Hello"

EOF
    chmod +x job.sh


    submit_to_custom_executor_queue job.sh


    wait_until_file_exists "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/OUTPUT/job.sh.out \
        $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME*2))

    echo "Logfile so far:"
    cat "$CUSTOM_EXECUTOR_QUEUE_LOGFILE" # For debugging
    echo "end of logfile"
    assert [ -f "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/OUTPUT/job.sh.out" ]
    run cat "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/OUTPUT/job.sh.out"
    # Making sure this has run 
    assert_output 'Hello'



}

@test "custom executor queue is sent SIGUSR1 before end of job and trap is activated" {


    ###############################################
    # STARTING CUSTOM EXECUTOR QUEUE IN SLURM JOB #
    ###############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 2 -n 1"
    JOB_ID=$("$SRC"/configure-slurm.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
	echo "squeue output:"
        squeue
        sleep 3
    done

    scontrol wait_job "$JOB_ID"

    wait_until_file_exists "$CEQ_ENV" 30


    # shellcheck disable=SC1090
    source "$CEQ_ENV"

    run sbatch -p dev_cpuonly -n 1 -t 1 \
        --dependency=afterany:"$JOB_ID" \
       	--wait \
	--wrap "grep -q 'Stopping custom executor queue...' $CUSTOM_EXECUTOR_QUEUE_LOGFILE"

    assert_success

}
