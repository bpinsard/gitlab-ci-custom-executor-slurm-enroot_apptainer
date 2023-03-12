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

    TEST_PLAYGROUND="$PWD/cleanup-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"

    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    echo "Test setup phase completed."


    # shellcheck disable=SC1090
    source <( "$SRC/configure-slurm.sh" 3> /dev/null | read-job-env.py )
    (
        # shellcheck source=./src/enroot-containerlib.sh
        source "$SRC/enroot-containerlib.sh"
        mkdir "$MOCKLOGDIR/.enroot-fakecontainers"
        touch "$MOCKLOGDIR/.enroot-fakecontainers/$CE_CONTAINER_NAME"

    )


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

@test "cleanup removes old custom executor queue workspaces" {

    assert false # not yet implemented

    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    "$SRC/cleanup-slurm.sh" enroot

    assert_dir_not_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"

}

@test "cleanup copies the CE queue workspaces to ~/ce-debug/cews_.../ if CUSTOM_ENV_CE_DEBUG is set" {

    assert false # not yet implemented

    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 15
    # This test requires that the container is set up
    "$SRC/prepare.sh" enroot

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CE_DEBUG=1
    # shellcheck disable=SC2030
    export CUSTOM_ENV_CE_DEBUG_DIR="$HOME/ce-debug-mocked"

    "$SRC/cleanup-slurm.sh" enroot
    assert_dir_not_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"
    assert_dir_exists "$CUSTOM_ENV_CE_DEBUG_DIR/cews_$CUSTOM_ENV_CI_JOB_ID"


}

@test "cleanup should complain if the wrong backend is passed as an argument" {

    export SYSTEM_FAILURE_EXIT_CODE=102
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    run "$SRC/cleanup-slurm.sh" nonexisting-backend
    assert_failure
    assert_output "ERROR: Not a valid backend: nonexisting-backend"

}

@test "cleanup asks for cancellation of scripts that belong to current CI_JOB" {

    assert false # not yet implemented

}

@test "cleanup scancels slurm job with SIGUSR1 if CUSTOM_ENV_KILL_SLURM is set to 1"  {

    assert false # not yet implemented

}

@test "cleanup kills slurm job with plain scancel after 5 sec if CUSTOM_ENV_KILL_SLURM is set to 1"  {

    assert false # not yet implemented

}
