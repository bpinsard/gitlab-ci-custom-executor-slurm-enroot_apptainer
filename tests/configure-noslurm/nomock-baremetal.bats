#!/usr/bin/env bash

function setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    export SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/configure-test-$BATS_TEST_NAME"
    
    echo "# Creating test playground in $TEST_PLAYGROUND" >&3
    rm -rf "$TEST_PLAYGROUND"
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export TEST_PLAYGROUND
    export STARTDIR="$TEST_PLAYGROUND"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || false

    echo "# Test setup phase completed." >&3

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_JOB_ID=54321

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci-ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42

    setup_allowed_gitlab_users_file
}

function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
}



@test "configure emits valid json" {

    "$SRC"/configure.sh none noslurm | json_validate

}
