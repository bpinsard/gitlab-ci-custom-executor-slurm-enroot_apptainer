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

    TEST_PLAYGROUND="$PWD/apptainer-prepare-test-$BATS_TEST_NAME"

    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    echo "Test setup phase completed."

}

teardown() {

    try_to_remove_dir "$TEST_PLAYGROUND"
}


@test "apptainer called with pull" {

    prepare-apptainer.sh
    assert_file_contains "$MOCKLOGDIR"/apptainer.log "ARGS:.*pull.*$CUSTOM_ENV_CI_JOB_IMAGE"

}

@test "APPTAINER_CACHEDIR is created in CI_WS" {

    prepare-apptainer.sh
    assert_dir_exists "$CUSTOM_ENV_CI_WS/.apptainer"

}

@test "apptainer pull call specifies image file CI_WS/image-CI_JOB_ID.sif" {

    prepare-apptainer.sh
    assert_file_contains "$MOCKLOGDIR"/apptainer.log  "ARGS:.*pull $CUSTOM_ENV_CI_WS/image-$CUSTOM_ENV_CI_JOB_ID.sif"

}

