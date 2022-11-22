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
}

function json_validate () {
    python3 -c 'import json,sys;json.load(sys.stdin)' || ( echo "JSON validation failed" && exit 1 )
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

function teardown() {
    wait_until_file_exists "$CUSTOM_ENV_CI_BUILDS_DIR"/.env 30
    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env
    # shellcheck disable=SC1091
    source "$SRC"/custom_executor_queue.sh
    stop_custom_executor_queue
    rm -r "$TEST_PLAYGROUND"

}


@test "sbatch called with --container-image" {

    "$SRC"/configure-slurm.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial '--container-image=alpine:latest'

}

@test "sbatch called with --container-mounts" {

    "$SRC"/configure-slurm.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial '--container-mounts='

}

@test "sbatch NOT called with --container-image when CUSTOM_ENV_CI_JOB_IMAGE not set" {

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_JOB_IMAGE=''
    "$SRC"/configure-slurm.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    refute_output --partial '--container-image'

}

@test "sbatch NOT called with --container-mounts when CUSTOM_ENV_CI_JOB_IMAGE not set" {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=''
    "$SRC"/configure-slurm.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    refute_output --partial '--container-mounts'

}


@test "sbatch invoked with '--propagate=NONE'" {

    "$SRC"/configure-slurm.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--propagate=NONE"


}

@test "sbatch invoked with '--parsable'" {

    "$SRC"/configure-slurm.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--parsable"


}

@test "sbatch invoked with '--signal=B:USR1@15'" {

    "$SRC"/configure-slurm.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--signal=B:USR1@15"


}



@test "sbatch invoked with --{input,output,error}=/dev/null" {

    "$SRC"/configure-slurm.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
    for STREAM in input output error
    do
    assert_output --partial "--${STREAM}=/dev/null"
    done

}
