#!/usr/bin/env bash

setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file/directory-related asserts
    load '../test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT
    load_mocks
    TEST_PLAYGROUND="$PWD/test-scontrol-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
    echo "Created test playground at $TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

}

teardown(){
    try_to_remove_dir "$TEST_PLAYGROUND"
}

@test "scontrol mock complains if no log location is given" {

    (
    # shellcheck disable=SC2030
    export MOCKLOGDIR=
    run scontrol some thing
    assert_equal "$status" 45
    )

}

@test "scontrol creates a logfile when invoked and writes its args there" {

    scontrol some thing

    # shellcheck disable=SC2031
    assert_exists "$MOCKLOGDIR"/scontrol.log
    # shellcheck disable=SC2031
    assert_file_contains "$MOCKLOGDIR"/scontrol.log "ARGS: some thing"

}
