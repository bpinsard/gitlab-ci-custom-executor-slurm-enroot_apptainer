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
    # export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    echo "Test setup phase completed."

}

function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
}


@test "job.slurm does finish when the custom executor queue process stops" {

    ( "$SRC/job.slurm"  "$TEST_PLAYGROUND/cews_0" "$SRC") &
    JOB_SLURM_PID=$!

    sleep 2
    CEQ_ENV="$TEST_PLAYGROUND/cews_0"/.env
    assert_exists "$CEQ_ENV"
    # shellcheck disable=SC1090
    source "$CEQ_ENV"
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"

    sleep 2
    assert custom_executor_queue_is_alive
    stop_custom_executor_queue
    while custom_executor_queue_is_alive
    do
        sleep 1
    done
    refute ps --pid "$JOB_SLURM_PID"

}
