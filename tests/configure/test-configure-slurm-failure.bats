#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load'
    load '../test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    load_mocks
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/configure-test-$BATS_TEST_NAME"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
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
    rm -r "$TEST_PLAYGROUND"

}


# bats test_tags=failure
@test "if CUSTOM_ENV_CI_WS is not defined, clear error message and hint should be printed" {

    (
        export CUSTOM_ENV_CI_WS=""
        export SYSTEM_FAILURE_EXIT_CODE=102
        run "$SRC"/configure-slurm.sh 3> /dev/null
        assert_failure
        assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
        assert_output --partial "CUSTOM_ENV_CI_WS variable not defined."
        assert_output --partial "Please define the CI_WS variable in your gitlab CI/CD setup (See README)."
    )


}
