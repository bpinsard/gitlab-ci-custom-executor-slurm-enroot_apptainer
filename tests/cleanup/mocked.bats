#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file-based operations
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PATH"
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND=$PWD/$(mktemp -d cleanup-testXXXXXXX)
    export MOCKLOGDIR=$TEST_PLAYGROUND
    echo "Created test playground at $TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    echo "Test setup phase completed."


    # shellcheck disable=SC1090
    source <( "$SRC/configure-slurm.sh" 3> /dev/null | read-job-env.py )


}

function teardown() {

    rm -rf "$TEST_PLAYGROUND"
}

function wait_until_file_exists() {
    local FILE="$1"
    local MAXDELAY="$2"
    local T0="$SECONDS"
    while [[ ! -f "$FILE" && "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done

}

@test "cleanup calls scancel with the right job id" {

    "$SRC/cleanup-slurm.sh"
    run cat "$MOCKLOGDIR/scancel.log"

    assert_line --partial "$CE_SLURM_JOB_ID"

}

@test "cleanup calls scancel --signal=SIGUSR1 and -f" {

    "$SRC/cleanup-slurm.sh"

    run cat "$MOCKLOGDIR/scancel.log"

    assert_line --partial "--signal=SIGUSR1"
    assert_line --partial "-f"

}

@test "cleanup calls plain scancel after 5 seconds" {

    "$SRC/cleanup-slurm.sh"  &
    wait_until_file_exists "$MOCKLOGDIR/scancel.log"
    run cat "$MOCKLOGDIR/scancel.log"

    refute_line "ARGS: $CE_SLURM_JOB_ID"
    # Additional 3 seconds for safety
    sleep 5 3
    run cat "$MOCKLOGDIR/scancel.log"
    assert_line "ARGS: $CE_SLURM_JOB_ID"


}

@test "cleanup removes the custom executor queue workspace" {

    wait_until_file_exists "$CE_CUSTOM_EXECUTOR_QUEUE_ENV_PATH" 10
    # shellcheck disable=SC1090
    source "$CE_CUSTOM_EXECUTOR_QUEUE_ENV_PATH"

    "$SRC/cleanup-slurm.sh"

    assert_dir_not_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"


}
