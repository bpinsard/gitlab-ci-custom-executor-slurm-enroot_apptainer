#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PATH"
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND=$PWD/$(mktemp -d configure-testXXXXXXX)
    export MOCKLOGDIR=$TEST_PLAYGROUND
    echo "Created test playground at $TEST_PLAYGROUND" >&3

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    CEQ_ENV="$CUSTOM_ENV_CI_BUILDS_DIR"/cews/.env
    echo "Test setup phase completed."
}

function teardown() {
    wait_until_file_exists "$CEQ_ENV" 30
    # shellcheck disable=SC1090
    source "$CEQ_ENV"
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC"/custom_executor_queue.sh
    stop_custom_executor_queue

    awk '{print $1}' "$MOCKLOGDIR"/pids.txt | xargs kill
    rm -r "$TEST_PLAYGROUND"
}


@test "sbatch invoked with '--propagate=NONE'" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--propagate=NONE"


}

@test "sbatch invoked with '--parsable'" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--parsable"


}

@test "sbatch invoked with '--signal=B:USR1@15'" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--signal=B:USR1@15"


}


@test "sbatch invoked with --{input,output,error}=/dev/null" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    for STREAM in input output error
    do
    assert_output --partial "--${STREAM}=/dev/null"
    done

}
