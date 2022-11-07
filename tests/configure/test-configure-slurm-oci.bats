#!/usr/bin/env bash

# This is based on the tutorial for bats
# https://bats-core.readthedocs.io/en/stable/tutorial.html

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
    cd "$STARTDIR"
}


function teardown() {
    rm -r $TEST_PLAYGROUND

}

@test "sbatch called with --container-image" {

    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest

    $SRC/configure-slurm-oci.sh > /dev/null

    run cat $MOCKLOGDIR/sbatch.log
    assert_output --partial '--container-image=alpine:latest'

}

@test "sbatch called with --container-mounts" {

    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest

    $SRC/configure-slurm-oci.sh > /dev/null

    run cat $MOCKLOGDIR/sbatch.log
    assert_output --partial '--container-mounts='

}

@test "/scratch in container mounts" {

    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    $SRC/configure-slurm-oci.sh > /dev/null

    run cat $MOCKLOGDIR/sbatch.log
    assert_output --partial '/scratch:/scratch'

}


@test "prolog script in container mounts" {

    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    $SRC/configure-slurm-oci.sh > /dev/null

    run cat $MOCKLOGDIR/sbatch.log
    assert_output --partial '/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk'

}

@test "allocation manager is started in slurm allocation" {

    local CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_BUILDS_DIR

    $SRC/configure-slurm-oci.sh

    cat $MOCKLOGDIR/sbatch.log

    assert [ -f "$TEST_PLAYGROUND"/.env ]
    source "$TEST_PLAYGROUND"/.env

    assert ps -q "$ALLOCATION_MANAGER_JOBID"




}
