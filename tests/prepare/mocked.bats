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
    export CE_QUEUE_WORKSPACE="$CUSTOM_ENV_CI_WS/cews_0"
    (
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC"/custom_executor_queue.sh
    start_custom_executor_queue "$CE_QUEUE_WORKSPACE" 3> /dev/null
    )
    export CUSTOM_ENV_CI_JOB_ID=54321
    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest


    echo "Test setup phase completed."
}

function teardown() {
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 30

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"
    # shellcheck disable=SC1091
    source "$SRC"/custom_executor_queue.sh
    stop_custom_executor_queue
    try_to_remove_dir "$TEST_PLAYGROUND"

}


@test "prepare uses enroot when enroot is passed as first argument" {
    prepare.sh enroot

    assert_exists "$MOCKLOGDIR"/enroot.log

}

@test "prepare uses singularity when singularity is passed as first argument" {

    prepare.sh singularity

    assert_exists "$MOCKLOGDIR"/singularity.log

}

@test "prepare uses the custom executor queue" {


    prepare.sh singularity

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"


    # shellcheck disable=SC2031
    DONEFILE="$(ls "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/DONE/wrap-prepare-*)"
    assert_exists "$DONEFILE"


}

@test "prepare exits with error when CUSTOM_ENV_CI_JOB_IMAGE is set but enroot or singularity are not passed as arguments" {

    #shellcheck disable=SC2030
    export SYSTEM_FAILURE_EXIT_CODE=102
    run prepare.sh none
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Job requires a container image but 'none' selected as backend."

}

@test "prepare communicates the containerisation backend" {
    (
    #shellcheck disable=SC2030,SC2031
    CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    run prepare.sh none
    assert_output --regexp "Containerisation backend: none"
    )
}

@test "prepare exits with error if the containerisation backend is not enroot, singularity or none" {

    #shellcheck disable=SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    run prepare.sh some-random-string
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Invalid containerisation backend: some-random-string"

}
