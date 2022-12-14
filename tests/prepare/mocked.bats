#!/usr/bin/env bash


function setup() {
    export TRACE=1
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    SRC="$PROJECT_ROOT"/src
    PATH="$PROJECT_ROOT/tests/mocks/bin:$SRC:$PATH"

    TEST_PLAYGROUND=$PWD/$(mktemp -d prepare-testXXXXXXX)
    export MOCKLOGDIR=$TEST_PLAYGROUND
    echo "Created test playground at $TEST_PLAYGROUND" >&3

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CE_CONTAINER_NAME=TestContainer
    echo "Test setup phase completed."

}

teardown() {

    rm -r "$TEST_PLAYGROUND"
}

@test "enroot called with import " {

    prepare-enroot.sh

    run cat "$MOCKLOGDIR"/enroot.log
    assert_line --partial "import docker://$CUSTOM_ENV_CI_JOB_IMAGE"

}
