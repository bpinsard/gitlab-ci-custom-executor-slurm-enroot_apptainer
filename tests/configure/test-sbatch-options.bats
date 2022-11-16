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
    echo "Test setup phase completed."
    "$SRC"/configure-slurm-oci.sh | json_validate
}

function json_validate () {
    python3 -c 'import json,sys;json.load(sys.stdin)' || ( echo "JSON validation failed" && exit 1 )
}

function teardown() {
    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env
    # shellcheck disable=SC1091
    source "$SRC"/allocation_manager.sh
    stop_allocation_manager
    rm -r "$TEST_PLAYGROUND"

}


@test "sbatch called with --container-image" {

    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial '--container-image=alpine:latest'

}

@test "sbatch called with --container-mounts" {

    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial '--container-mounts='

}

@test "sbatch called with '--export=NONE'" {

    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--export=NONE"

}

@test "sbatch invoked with '--propagate=NONE'" {

    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--propagate=NONE"


}

@test "sbatch invoked with --{input,output,error}=/dev/null" {

    run cat "$MOCKLOGDIR"/sbatch.log
    for STREAM in input output error
    do
    assert_output --partial "--${STREAM}=/dev/null"
    done

}
