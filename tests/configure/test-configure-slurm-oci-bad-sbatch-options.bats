#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PATH"
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND=$PWD/$(mktemp -d configure-testXXXXXXX)
    export MOCKLOGDIR=$TEST_PLAYGROUND
    echo "Created test playground at $TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export SYSTEM_FAILURE_EXIT_CODE=103 # A random-value, please change if needed
    echo "Test setup phase completed."
}

function teardown() {
    rm -r "$TEST_PLAYGROUND"
}


@test "when \$COMMAND_OPTIONS_SBATCH contains --container-image, do lament on stderr" {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--container-image=fuzz"
    local STDOUT="$TEST_PLAYGROUND/.stdout.test"
    local STDERR="$TEST_PLAYGROUND/.stderr.test"
    "$SRC"/configure-slurm-oci.sh 1> "$STDOUT" 2> "$STDERR" || true #

    run cat "$STDERR"
    assert_output --partial "Error: please do not use --container-image in \$COMMAND_OPTIONS_SBATCH."

}

@test "when \$COMMAND_OPTIONS_SBATCH contains --container-mounts, do lament on stderr" {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--container-mounts=/fuzz:/fuzz"
    local STDOUT="$TEST_PLAYGROUND/.stdout.test"
    local STDERR="$TEST_PLAYGROUND/.stderr.test"
    "$SRC"/configure-slurm-oci.sh 1> "$STDOUT" 2> "$STDERR" || true #

    run cat "$STDERR"
    assert_output --partial "Error: please do not use --container-mounts in \$COMMAND_OPTIONS_SBATCH."

}

@test "when \$COMMAND_OPTIONS_SBATCH contains a 'forbidden' option, die with \$SYSTEM_FAILURE_EXIT_CODE" {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--container-image=fuzz"
    run "$SRC"/configure-slurm-oci.sh
    assert_failure "$SYSTEM_FAILURE_EXIT_CODE"

}
