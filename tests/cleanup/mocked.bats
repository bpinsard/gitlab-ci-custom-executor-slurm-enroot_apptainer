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

    TEST_PLAYGROUND=$PWD/$(mktemp -d cleanup-testXXXXXXX)

    export MOCKLOGDIR=$TEST_PLAYGROUND
    echo "# Created test playground at $TEST_PLAYGROUND" >&3

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    echo "Test setup phase completed."


    # shellcheck disable=SC1090
    source <( "$SRC/configure-slurm.sh" 3> /dev/null | read-job-env.py )


}

function teardown() {
    awk '{print $1}' "$MOCKLOGDIR"/pids.txt | xargs kill
    rm -rf "$TEST_PLAYGROUND"
    rm -rf "$HOME/ce-debug/cews_$CUSTOM_ENV_CI_JOB_ID"
}
function teardown_file(){
    rm -rf "$HOME/ce-debug/"
}
@test "cleanup calls scancel with the right job id" {
    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 90
    "$SRC/cleanup-slurm.sh"
    run cat "$MOCKLOGDIR/scancel.log"

    assert_line --partial "$CE_SLURM_JOB_ID"

}

@test "cleanup calls scancel --batch --signal=SIGUSR1 and -f" {
    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 90

    "$SRC/cleanup-slurm.sh"

    run cat "$MOCKLOGDIR/scancel.log"

    assert_line --partial "--signal=SIGUSR1"
    assert_line --partial "--batch"
    assert_line --partial "-f"

}

@test "cleanup calls plain scancel after 5 seconds" {

    "$SRC/cleanup-slurm.sh"  &
    wait_until_file_exists "$MOCKLOGDIR/scancel.log" 10
    refute  grep -q "ARGS: $CE_SLURM_JOB_ID" "$MOCKLOGDIR/scancel.log"
    # Additional 3 seconds for safety
    sleep 5 3
    assert  grep -q "ARGS: $CE_SLURM_JOB_ID" "$MOCKLOGDIR/scancel.log"


}

@test "cleanup removes the custom executor queue workspace" {

    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 10
    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"

    "$SRC/cleanup-slurm.sh"

    assert_dir_not_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"

}

@test "cleanup copies the CE queue workspace to ~/ce-debug/cews_.../ if CUSTOM_ENV_CE_DEBUG is set" {

    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 15
    # This test requires that the container is set up
    "$SRC/prepare-enroot.sh"

    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CE_DEBUG=1

    "$SRC/cleanup-slurm.sh"
    assert_dir_not_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"
    assert_dir_exists "$HOME/ce-debug/cews_$CUSTOM_ENV_CI_JOB_ID"


}

@test "cleanup removes enroot container" {

    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 10
    # This test requires that enroot is invoked
    "$SRC/prepare-enroot.sh"
    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"

    "$SRC/cleanup-slurm.sh"

    # Out mock is not so clever, this does not work.
    # _helper(){ enroot list | wc -l; }


    run cat "$MOCKLOGDIR/enroot.log"
    # shellcheck source=./src/containerlib.sh
    source "$SRC"/containerlib.sh
    assert_output --regexp "remove.*$CE_CONTAINER_NAME"

}

@test "cleanup removes enroot image" {

    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 10
    # This test requires that enroot is invoked
    "$SRC/prepare-enroot.sh"
    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"

    "$SRC/cleanup-slurm.sh"

    # shellcheck source=./src/containerlib.sh
    source "$SRC"/containerlib.sh

    assert_not_exists "$CE_IMAGEFILE"

}

@test "cleanup does not call enroot at all when image not needed" {


    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 10

    (
        export CUSTOM_ENV_CI_JOB_IMAGE=""
        # shellcheck disable=SC1090
        source "$CE_QUEUE_ENV_PATH"
        "$SRC/cleanup-slurm.sh"
        assert_not_exists "$MOCKLOGDIR/enroot.log"
    )
}

@test "enroot container should not be removed if CUSTOM_ENV_CE_DEBUG is set" {

    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 10

    # We need this preparation step for container stuff
    "$SRC/prepare-enroot.sh"

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG=1

    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"
    "$SRC/cleanup-slurm.sh"

    run cat "$MOCKLOGDIR/enroot.log"
    refute_output --partial "remove"

}
