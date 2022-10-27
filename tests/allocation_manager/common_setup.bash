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
    TEST_PLAYGROUND=$(mktemp -d alloc-manager-testXXXXXXX)
    echo "Created test playground at $TEST_PLAYGROUND"

}


function _common_teardown() {
    rm -r $TEST_PLAYGROUND
}

function _no_allocation_manager_variables_declared() {
    #local ndeclared=$(env | grep -E '^ALLOCATION_MANAGER' | wc -l )
    local ndeclared=$( echo "${!ALLOCATION_MANAGER*}" | wc -w )
    [ $ndeclared -eq 0 ]
}
