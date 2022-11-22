#!/usr/bin/env bash

# This is based on the tutorial for bats
# https://bats-core.readthedocs.io/en/stable/tutorial.html

function _common_setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading
    PATH="$PROJECT_ROOT/src:$PATH"
    TEST_PLAYGROUND=$PWD/$(mktemp -d alloc-manager-testXXXXXXX)
    echo "Created test playground at $TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR"
}


function _common_teardown() {
    rm -rf $TEST_PLAYGROUND

}

function _no_custom_executor_queue_variables_declared() {
    #local ndeclared=$(env | grep -E '^CUSTOM_EXECUTOR_QUEUE' | wc -l )
    local ndeclared=$( echo "${!CUSTOM_EXECUTOR_QUEUE*}" | wc -w )
    [ $ndeclared -eq 0 ]
}
