#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    load_mocks
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/configure-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    CEQ_ENV="$CUSTOM_ENV_CI_WS/cews_$CUSTOM_ENV_CI_JOB_ID"/.env
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
    assert_file_contains "$MOCKLOGDIR"/sbatch.log "\-\-propagate=NONE"


}

@test "sbatch invoked with '--parsable'" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    assert_file_contains "$MOCKLOGDIR"/sbatch.log "\-\-parsable"


}

@test "sbatch invoked with '--signal=B:USR1@15'" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    assert_file_contains "$MOCKLOGDIR"/sbatch.log "\-\-signal=B:USR1@15"


}


@test "sbatch invoked with --{input,output,error}=/dev/null" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    for STREAM in input output error
    do
        assert_file_contains "$MOCKLOGDIR"/sbatch.log "\-\-${STREAM}=/dev/null"
    done

}

@test "sbatch NOT invoked with --{input,output,error}=/dev/null when CUSTOM_ENV_CE_DEBUG is set." {

    (
    export CUSTOM_ENV_CE_DEBUG=1
    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    for STREAM in input output error
    do
    refute_output --partial "--${STREAM}=/dev/null"
    done
    )

}
