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

    TEST_PLAYGROUND="$PWD/cleanup-test-enroot-mocked-noslurm-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"

    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci_ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42

    export CUSTOM_ENV_CI_JOB_IMAGE=docker://alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_DEFAULT_PARTITION=default-partition
    setup_allowed_gitlab_users_file
    echo "Test setup phase completed."


    # shellcheck disable=SC1090
    source <( "$SRC/configure.sh" enroot noslurm 3> /dev/null | read-job-env.py )


}

function teardown() {
    rm -rf "$TEST_PLAYGROUND"
    set +o nounset
    if [ -n "$CUSTOM_ENV_CE_DEBUG_DIR" ]
    then
    rm -rf "$CUSTOM_ENV_CE_DEBUG_DIR/cews_$CUSTOM_ENV_CI_JOB_ID"
    fi
    set -o nounset

}

@test "cleanup removes enroot container (no slurm)" {

    # This test requires that enroot is invoked
    "$SRC/prepare-enroot.sh"

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CE_DEBUG_LVL=
    "$SRC/cleanup.sh" enroot noslurm

    # Out mock is not so clever, this does not work.
    # _helper(){ enroot list | wc -l; }


    # shellcheck source=./src/containerlib-enroot.sh
    source "$SRC"/containerlib-enroot.sh
    assert_file_contains "$MOCKLOGDIR/enroot.log" "\bremove\b.*$CE_CONTAINER_NAME"
    assert_file_contains "$MOCKLOGDIR/enroot.log" '^y$'

}

@test "cleanup removes enroot container even when CI_JOB_IMAGE is not present but IMAGEFILE is (no slurm)" {

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_JOB_IMAGE=""
    export CUSTOM_ENV_IMAGEFILE="a-file.sqsh"
    # This test requires that enroot is invoked
    "$SRC/prepare-enroot.sh"

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CE_DEBUG_LVL=
    "$SRC/cleanup.sh" enroot noslurm

    # Out mock is not so clever, this does not work.
    # _helper(){ enroot list | wc -l; }


    # shellcheck source=./src/containerlib-enroot.sh
    source "$SRC"/containerlib-enroot.sh
    assert_file_contains "$MOCKLOGDIR/enroot.log" "\bremove\b.*$CE_CONTAINER_NAME"
    assert_file_contains "$MOCKLOGDIR/enroot.log" '^y$'

}


@test "cleanup does not call enroot at all when image not needed (no slurm)" {


    (
        # shellcheck disable=SC2031
        export CUSTOM_ENV_CI_JOB_IMAGE=""
        "$SRC/cleanup.sh" enroot noslurm
        assert_not_exists "$MOCKLOGDIR/enroot.log"
    )
}

@test "enroot container should not be removed if CUSTOM_ENV_CE_DEBUG_LVL > 1 (no slurm)" {


    # We need this preparation step for container stuff
    "$SRC/prepare-enroot.sh"

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CE_DEBUG_LVL=2
    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CE_DEBUG_DIR="$HOME/ce-debug-mocked-enroot"

    "$SRC/cleanup.sh" enroot noslurm

    run cat "$MOCKLOGDIR/enroot.log"
    refute_line --regexp "\sremove\s"

}

@test "enroot container should still be removed if CUSTOM_ENV_CE_DEBUG_LVL = 1 (no slurm)" {


    # We need this preparation step for container stuff
    "$SRC/prepare-enroot.sh"

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG_LVL=1
    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG_DIR="$HOME/ce-debug-mocked-enroot"

    "$SRC/cleanup.sh" enroot noslurm

    run cat "$MOCKLOGDIR/enroot.log"
    assert_line --regexp "\sremove\s"

}
