#!/usr/bin/env bash


setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for assert_output and refute_output
    load '../test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT

    load_mocks

    TEST_PLAYGROUND=$PWD/$(mktemp -d realpath-mock-testXXXXXXX)
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
    echo "Created test playground at $TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

}

teardown() {

    rm -r "$TEST_PLAYGROUND"

}

@test "realpath mock complains if no log location is given" {

    (
    # shellcheck disable=SC2030
    export MOCKLOGDIR=
    run realpath soomething
    assert_equal "$status" 45
    )

}

@test "realpath mock records args in log" {

    realpath something like this
    run cat "$MOCKLOGDIR"/realpath.log
    assert_output --partial "something like this"
}
