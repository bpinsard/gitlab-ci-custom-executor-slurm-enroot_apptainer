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

    TEST_PLAYGROUND="$PWD/cleanup-test-enroot-mocked-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"

    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=docker://alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    echo "Test setup phase completed."


    # shellcheck disable=SC1090
    source <( "$SRC/configure-slurm.sh" 3> /dev/null | read-job-env.py )


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


@test "cleanup removes enroot container" {

    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10
    # This test requires that enroot is invoked
    "$SRC/prepare-enroot.sh"
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    "$SRC/cleanup-slurm.sh" enroot

    # Out mock is not so clever, this does not work.
    # _helper(){ enroot list | wc -l; }


    # shellcheck source=./src/enroot-containerlib.sh
    source "$SRC"/enroot-containerlib.sh
    assert_file_contains "$MOCKLOGDIR/enroot.log" "\bremove\b.*$CE_CONTAINER_NAME"

}

@test "cleanup does not call enroot at all when image not needed" {


    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    (
        export CUSTOM_ENV_CI_JOB_IMAGE=""
        # shellcheck disable=SC1091
        source "$CE_QUEUE_WORKSPACE/.env"
        "$SRC/cleanup-slurm.sh" enroot
        assert_not_exists "$MOCKLOGDIR/enroot.log"
    )
}

@test "enroot container should not be removed if CUSTOM_ENV_CE_DEBUG is set" {

    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # We need this preparation step for container stuff
    "$SRC/prepare-enroot.sh"

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG=1
    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG_DIR="$HOME/ce-debug-mocked-enroot"

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"
    "$SRC/cleanup-slurm.sh" enroot

    run cat "$MOCKLOGDIR/enroot.log"
    refute_line --regexp "\sremove\s"

}
