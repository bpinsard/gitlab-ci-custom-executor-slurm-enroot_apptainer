#!/usr/bin/env bash

function setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    export SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/job-slurm-test-$BATS_TEST_NAME"

    echo "# Creating test playground in $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit


    declare -g JOB_SLURM
    # shellcheck source=./src/configure-slurm-include.sh
    JOB_SLURM="$(source "$SRC/configure-slurm-include.sh";
                 create_job_slurm "$SRC/job.slurm.template" \
                                  default-partition-name \
                                  600 \
                                 "$TEST_PLAYGROUND")"
    export JOB_SLURM


    echo "Test setup phase completed."

}

function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
}


@test "job.slurm does finish when the custom executor queue process stops" {

    echo "JS: $JOB_SLURM"
    echo "Running $JOB_SLURM..."
    assert [ -x "$JOB_SLURM" ]
    # shellcheck disable=SC2031
    ( "$JOB_SLURM"  "$TEST_PLAYGROUND/cews_0" "$SRC") &
    JOB_SLURM_PID=$!

    sleep 2
    CEQ_ENV="$TEST_PLAYGROUND/cews_0"/.env
    echo "Content of TEST_PLAYGROUND ($TEST_PLAYGROUND):"
    ( cd  "$TEST_PLAYGROUND"; find . )
    assert_exists "$CEQ_ENV"
    # shellcheck disable=SC1090
    source "$CEQ_ENV"
    echo "Contents of $CEQ_ENV:"
    cat "$CEQ_ENV"
    # shellcheck source=./src/custom_executor_queue.sh disable=SC2031
    source "$SRC/custom_executor_queue.sh"

    sleep 2
    echo "Content of logfile so far:"
    cat "$TEST_PLAYGROUND/cews_0"/log.txt
    assert custom_executor_queue_is_alive
    stop_custom_executor_queue
    while custom_executor_queue_is_alive
    do
        sleep 1
    done
    sleep 2
    refute ps --pid "$JOB_SLURM_PID"

}
