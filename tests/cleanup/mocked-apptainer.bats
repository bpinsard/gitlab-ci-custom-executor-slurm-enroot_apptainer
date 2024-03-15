#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file-based operations
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    load_mocks
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/cleanup-test-sing-mocked-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"

    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci-ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_DEFAULT_PARTITION=default-partition


    setup_allowed_committers_file

    echo "Test setup phase completed."


    # shellcheck disable=SC1090
    source <( "$SRC/configure.sh" apptainer useslurm 3> /dev/null | read-job-env.py )


}

function teardown() {
    awk '{print $1}' "$MOCKLOGDIR"/pids.txt | xargs kill
    rm -rf "$TEST_PLAYGROUND"
    set +o nounset
    if [ -n "$CUSTOM_ENV_CE_DEBUG_DIR" ]
    then
    rm -rf "$CUSTOM_ENV_CE_DEBUG_DIR/cews_$CUSTOM_ENV_CI_JOB_ID"
    fi
    set -o nounset
}


function teardown_file(){
    set +o nounset
    if [ -n "$CUSTOM_ENV_CE_DEBUG_DIR" ]
    then
    rm -rf "$CUSTOM_ENV_CE_DEBUG_DIR"
    fi
    set -o nounset
}


@test "cleanup removes apptainer image" {

    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10
    # This test requires that apptainer is invoked
    "$SRC/prepare-apptainer.sh"
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CE_DEBUG_LVL=
    "$SRC/cleanup.sh" apptainer useslurm

    # shellcheck source=./src/containerlib-apptainer.sh
    source "$SRC"/containerlib-apptainer.sh

    assert_not_exists "$CE_IMAGEFILE"

}

@test "cleanup does not call apptainer at all when image not needed" {


    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    (
        # shellcheck disable=SC2030
        export CUSTOM_ENV_CI_JOB_IMAGE=""
        # shellcheck disable=SC1091
        source "$CE_QUEUE_WORKSPACE/.env"
        "$SRC/cleanup.sh" apptainer useslurm
        assert_not_exists "$MOCKLOGDIR/apptainer.log"
    )
}

@test "apptainer image should not be removed if CUSTOM_ENV_CE_DEBUG_LVL > 1" {
    (
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # We need this preparation step for container stuff
    "$SRC/prepare-apptainer.sh"

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CE_DEBUG_LVL=2
    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CE_DEBUG_DIR="$HOME/ce-debug-mocked-apptainer"


    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    "$SRC/cleanup.sh" apptainer useslurm

    # shellcheck source=./src/containerlib-apptainer.sh
    source "$SRC"/containerlib-apptainer.sh

    assert_exists "$CE_IMAGEFILE"
    )
}
@test "apptainer image should still be removed if CUSTOM_ENV_CE_DEBUG_LVL = 1" {
    (
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # We need this preparation step for container stuff
    "$SRC/prepare-apptainer.sh"

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CE_DEBUG_LVL=1
    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG_DIR="$HOME/ce-debug-mocked-apptainer"


    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    "$SRC/cleanup.sh" apptainer useslurm

    # shellcheck source=./src/containerlib-apptainer.sh
    source "$SRC"/containerlib-apptainer.sh

    assert_not_exists "$CE_IMAGEFILE"
    )
}


@test "when CUSTOM_ENV_IMAGEFILE is defined, that file is not deleted" {

    #shellcheck disable=SC2030
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/afile.sif"
    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # We need this preparation step for container stuff
    "$SRC/prepare-apptainer.sh"

    echo "Prepared..."
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    touch "$CUSTOM_ENV_IMAGEFILE"

    run "$SRC/cleanup.sh" apptainer useslurm

    echo "Cleaned."
    assert_exists "$CUSTOM_ENV_IMAGEFILE"

}

@test "when IMAGEFILE and CI_JOB_IMAGE are defined, IMAGEFILE is not deleted - no message" {

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/afile.sif"
    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE="docker://debian:latest"
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # We need this preparation step for container stuff
    "$SRC/prepare-apptainer.sh"

    echo "Prepared..."
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    touch "$CUSTOM_ENV_IMAGEFILE"
    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CE_DEBUG_LVL=0

    run "$SRC/cleanup.sh" apptainer useslurm

    echo "Cleaned."
    assert_exists "$CUSTOM_ENV_IMAGEFILE"
    refute_output --partial "Not Removing"

}


@test "IMAGEFILE,CI_JOB_IMAGE defined, CE_DEBUG_LVL > 0, then message IMAGEFILE not deleted" {
    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/afile.sif"
    #shellcheck disable=SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE="docker://debian:latest"
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # We need this preparation step for container stuff
    "$SRC/prepare-apptainer.sh"

    echo "Prepared..."
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    touch "$CUSTOM_ENV_IMAGEFILE"

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG_LVL=1
    run "$SRC/cleanup.sh" apptainer useslurm

    echo "Cleaned."
    assert_exists "$CUSTOM_ENV_IMAGEFILE"
    assert_output --partial "Not Removing"

}
