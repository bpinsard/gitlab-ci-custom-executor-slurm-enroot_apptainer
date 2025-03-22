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
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"

    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci-ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42

    export CUSTOM_ENV_CI_JOB_IMAGE=docker://alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_DEFAULT_PARTITION=default-partition
    echo "Test setup phase completed."


    # shellcheck disable=SC1090
    source <( "$SRC/configure.sh" none noslurm 3> /dev/null | read-job-env.py )

    (
        # shellcheck source=./src/containerlib-enroot.sh
        source "$SRC/containerlib-enroot.sh"
        mkdir "$MOCKLOGDIR/.enroot-fakecontainers"
        touch "$MOCKLOGDIR/.enroot-fakecontainers/$CE_CONTAINER_NAME"
    )


}

function teardown() {
    rm -rf "$TEST_PLAYGROUND"
}

@test "cleanup should complain if the wrong backend is passed as an argument and image is used (no slurm)" {

    #shellcheck disable=SC2030
    export SYSTEM_FAILURE_EXIT_CODE=102

    run "$SRC/cleanup.sh" nonexisting-backend noslurm
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Invalid containerisation backend: nonexisting-backend"
}

@test "cleanup should be happy if 'none' is passed as an argument and image is not used (no slurm)" {

    export CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

    run "$SRC/cleanup.sh" none noslurm
    assert_success
}

@test "cleanup complains if 'none' is passed as an argument and image is used (no slurm)" {

    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

    run "$SRC/cleanup.sh" none noslurm
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Job requires a container image but 'none' selected as backend."
}


@test "when CUSTOM_ENV_CI_JOB_IMAGE is not set, no errors (set to empty string) (no slurm)" {

    unset CUSTOM_ENV_CI_JOB_IMAGE


    run "$SRC/cleanup.sh" enroot noslurm
    assert_success
    assert_not_exists "$MOCKLOGDIR/enroot.log"

}
