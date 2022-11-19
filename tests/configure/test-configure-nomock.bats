#!/usr/bin/env bash

function setup(){

    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    export SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/$(mktemp -d configure-testXXXXXXX)"
    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    cat << EOF > get_jobid.py
import sys, json
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_SLURM_JOB_ID"])
EOF


    echo "Test setup phase completed."

}

function _on_horeka() {
   hostname | grep -q -E "hkn[0-9]{4}.localdomain"
}


function teardown() {
    echo scancel "$JOB_ID"
    scancel "$JOB_ID"
    echo rm -r "$TEST_PLAYGROUND"
    rm -r "$TEST_PLAYGROUND"
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


@test "configure launches allocation manager in slurm job - no container" {

    _on_horeka || skip

    # shellcheck disable=SC2030
    CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_BUILDS_DIR
    mkdir -p "$CUSTOM_ENV_CI_BUILDS_DIR" # This should not be needed

    # shellcheck disable=SC2030
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 1 -n 1"
    # shellcheck disable=SC2030
    export CUSTOM_ENV_CE_DEBUG=1
    

    JOB_ID=$("$SRC"/configure-slurm-oci.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
    sleep 1
    done

    scontrol wait_job "$JOB_ID"

    wait_until_file_exists "$CUSTOM_ENV_CI_BUILDS_DIR"/.env 30

    assert [ -f "$CUSTOM_ENV_CI_BUILDS_DIR"/.env ]

}

@test "configure launches allocation manager in slurm job - with container" {

    _on_horeka || skip

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_JOB_IMAGE="bash:latest"
    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    mkdir -p "$CUSTOM_ENV_CI_BUILDS_DIR" # This should not be needed

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 1 -n 3"
    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CE_DEBUG=1
    

    JOB_ID=$("$SRC"/configure-slurm-oci.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
    sleep 1
    done

    scontrol wait_job "$JOB_ID"

    wait_until_file_exists "$CUSTOM_ENV_CI_BUILDS_DIR"/.env 90

    assert [ -f "$CUSTOM_ENV_CI_BUILDS_DIR"/.env ]

}


@test "configure launches allocation manager in slurm job - with container - submission" {

    _on_horeka || skip

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE="ubuntu:kinetic-20221101"
    # shellcheck disable=SC2031
    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    mkdir -p "$CUSTOM_ENV_CI_BUILDS_DIR" # This should not be needed
    # shellcheck disable=SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 3 -n 1"
    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG=1
    

    JOB_ID=$("$SRC"/configure-slurm-oci.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
    sleep 1
    done

    scontrol wait_job "$JOB_ID"
   
    ENVFILE="$CUSTOM_ENV_CI_BUILDS_DIR"/.env

    wait_until_file_exists "$ENVFILE" 100

    # shellcheck disable=SC1090
    source "$ENVFILE"
    # shellcheck disable=SC1091
    source "$SRC"/allocation_manager.sh

    cat << EOF > job.sh
#!/bin/bash
grep PRETTY /etc/os-release

EOF
    chmod +x job.sh


    submit_to_allocation_manager job.sh


    wait_until_file_exists "${ALLOCATION_MANAGER_WORKSPACE}"/OUTPUT/job.sh.out \
        $((ALLOCATION_MANAGER_CYCLETIME*2))

    assert [ -f "${ALLOCATION_MANAGER_WORKSPACE}"/OUTPUT/job.sh.out ]
    run cat "${ALLOCATION_MANAGER_WORKSPACE}"/OUTPUT/job.sh.out
    assert_output  'PRETTY_NAME="Ubuntu 22.10"'

}

