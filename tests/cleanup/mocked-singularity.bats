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


}

function teardown() {
    awk '{print $1}' "$MOCKLOGDIR"/pids.txt | xargs kill
    rm -rf "$TEST_PLAYGROUND"
    rm -rf "$HOME/ce-debug/cews_$CUSTOM_ENV_CI_JOB_ID"
}

function teardown_file(){
    rm -rf "$HOME/ce-debug/"
}


@test "cleanup removes singularity image" {

    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 10
    # This test requires that singularity is invoked
    "$SRC/prepare-singularity.sh"
    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"

    "$SRC/cleanup-slurm.sh" singularity

    # shellcheck source=./src/singularity-containerlib.sh
    source "$SRC"/singularity-containerlib.sh

    assert_not_exists "$CE_IMAGEFILE"

}

@test "cleanup does not call singularity at all when image not needed" {


    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 10

    (
        # shellcheck disable=SC2030
        export CUSTOM_ENV_CI_JOB_IMAGE=""
        # shellcheck disable=SC1090
        source "$CE_QUEUE_ENV_PATH"
        "$SRC/cleanup-slurm.sh" singularity
        assert_not_exists "$MOCKLOGDIR/singularity.log"
    )
}

@test "singularity image should not be removed if CUSTOM_ENV_CE_DEBUG is set" {

    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 10

    # We need this preparation step for container stuff
    "$SRC/prepare-singularity.sh"

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG=1

    # shellcheck disable=SC1090
    source "$CE_QUEUE_ENV_PATH"
    "$SRC/cleanup-slurm.sh" singularity

    # shellcheck source=./src/singularity-containerlib.sh
    source "$SRC"/singularity-containerlib.sh

    assert_exists "$CE_IMAGEFILE"

}
