#!/usr/bin/env bash

function setup(){

    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    SRC="$PROJECT_ROOT"/src
    export PATH="$SRC:$PATH"
    load_mocks

    TEST_PLAYGROUND="$PWD/singularity-prepare-test-$BATS_TEST_NAME"

    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CE_CONTAINER_NAME="GLCE_54321"
    export CE_IMAGEFILE="$CUSTOM_ENV_CI_WS/image_${CE_CONTAINER_NAME}.sqsh"
    echo "Test setup phase completed."

}

teardown() {

    rm -r "$TEST_PLAYGROUND"
}


@test "singularity called with pull" {

    prepare-singularity.sh

    run cat "$MOCKLOGDIR"/singularity.log
    assert_line --regexp "ARGS:.*.*docker://$CUSTOM_ENV_CI_JOB_IMAGE"

}
