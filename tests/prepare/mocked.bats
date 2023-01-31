#!/usr/bin/env bash

function setup() {
    export TRACE=1
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    SRC="$PROJECT_ROOT"/src
    export PATH="$SRC:$PATH"
    load_mocks

    TEST_PLAYGROUND="$PWD/prepare-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit


    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_ID=54321
    (
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC"/custom_executor_queue.sh
    start_custom_executor_queue "$CUSTOM_ENV_CI_WS/cews_$CUSTOM_ENV_CI_JOB_ID" 3> /dev/null
    )
    export CE_QUEUE_ENV_PATH="$CUSTOM_ENV_CI_WS/cews_$CUSTOM_ENV_CI_JOB_ID"/.env


    echo "Test setup phase completed."
}

function teardown() {
    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 30

    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"
    # shellcheck disable=SC1091
    source "$SRC"/custom_executor_queue.sh
    stop_custom_executor_queue
    rm -r "$TEST_PLAYGROUND"

}



@test "prepare uses enroot when enroot is passed as first argument" {
    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    # shellcheck disable=SC2030
    export CE_CONTAINER_NAME="GLCE_54321"
    # shellcheck disable=SC2030
    export CE_IMAGEFILE="$CUSTOM_ENV_CI_WS/image_${CE_CONTAINER_NAME}.sqsh"

    prepare.sh enroot

    assert_exists "$MOCKLOGDIR"/enroot.log

}

@test "prepare uses singularity when singularity is passed as first argument" {
    # shellcheck disable=SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    # shellcheck disable=SC2031
    export CE_CONTAINER_NAME="GLCE_54321"
    # shellcheck disable=SC2031
    export CE_IMAGEFILE="$CUSTOM_ENV_CI_WS/image_${CE_CONTAINER_NAME}.sqsh"

    prepare.sh singularity

    assert_exists "$MOCKLOGDIR"/singularity.log

}

@test "prepare uses the custom executor queue" {


    # shellcheck disable=SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    # shellcheck disable=SC2031
    export CE_CONTAINER_NAME="GLCE_54321"
    # shellcheck disable=SC2031
    export CE_IMAGEFILE="$CUSTOM_ENV_CI_WS/image_${CE_CONTAINER_NAME}.sqsh"

    prepare.sh singularity

    source "$CE_QUEUE_ENV_PATH"
    assert_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/DONE/prepare-singularity.sh"


}
