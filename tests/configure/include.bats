#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load'
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    load_mocks

    SRC="$PROJECT_ROOT/src"
    #shellcheck source=./src/configure-include.sh
    source "$SRC"/configure-include.sh

    TEST_PLAYGROUND="$PWD/configure-include-test-$BATS_TEST_NAME"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
}


function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
}

@test "get_gitlab_username_from_job_token can read correctly the username in the json response" {

    run get_gitlab_username_from_job_token

    assert_output some.one

}
