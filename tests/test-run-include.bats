#!/usr/bin/env bash


function setup() {
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    SRC="$PROJECT_ROOT/src"
    # shellcheck disable=SC1091
    source "$SRC"/run-include.sh

    TEST_PLAYGROUND=$PWD/$(mktemp -d run-include-testXXXXXXX)
    export MOCKLOGDIR="$TEST_PLAYGROUND"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    }

function teardown() {
    rm -r "$TEST_PLAYGROUND"
}


@test "get_abs_path works as expected" {

    mkdir -p ./a/path/here
    run get_abs_path ./a/path/here/thing

    assert_output "$STARTDIR"/a/path/here/thing

}
