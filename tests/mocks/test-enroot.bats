#!/usr/bin/env bash

setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PATH"
    TEST_PLAYGROUND=$PWD/$(mktemp -d enroot-mock-testXXXXXXX)
    echo "Created test playground at $TEST_PLAYGROUND" >&3
    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
    echo "Created test playground at $TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

}

teardown() {

    rm -r "$TEST_PLAYGROUND"

}
@test "enroot mock complains if no log location is given" {

    (
    # shellcheck disable=SC2030
    export MOCKLOGDIR=
    run enroot --something
    assert_equal "$status" 45
    )

}


@test "enroot mock record logs at given location" {

    enroot --something
    assert_file_exists "$MOCKLOGDIR"/enroot.log

}

@test "enroot mock record ENROOT* environmen variables" {


    export ENROOT_

    enroot --something


}
