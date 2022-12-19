#!/usr/bin/env bash

setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file/directory-related asserts
    load '../test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT
    load_mocks
    TEST_PLAYGROUND=$PWD/$(mktemp -d scancel-mock-testXXXXXXX)
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
    echo "Created test playground at $TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND


}

teardown(){
    rm -r "$TEST_PLAYGROUND"
}

@test "scancel mock complains if no log location is given" {

    (
    # shellcheck disable=SC2030
    export MOCKLOGDIR=
    run scancel 123840
    assert_equal "$status" 1
    )

}

@test "scancel mock records logs at a given location" {

    scancel 123480
    # shellcheck disable=SC2031
    assert_exists "$MOCKLOGDIR/scancel.log"

}
