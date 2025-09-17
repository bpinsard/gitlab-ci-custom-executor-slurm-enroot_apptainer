#!/usr/bin/env bash

function has_slurm_and_enroot() {
    type -p srun &> /dev/null && type -p enroot &> /dev/null
}

function get_slurm_default_partition() {
    scontrol show partition | grep -e "dev_\(single\|cpuonly\)" | cut -d= -f2
}

function on_horeka () {
    hostname | grep -q -E "hkn[0-9]{4}.localdomain" 
}

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading
    PATH="$PROJECT_ROOT/src:$PATH"

    TEST_PLAYGROUND="$PWD/contract-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    # Apparently, these variables are anyway ignored by enroot
    # when running inside pyxis
    export ENROOT_RUNTIME_PATH="$TEST_PLAYGROUND/run/enroot"
    export ENROOT_CONFIG_PATH="$TEST_PLAYGROUND/conf/enroot"
    export ENROOT_CACHE_PATH="$TEST_PLAYGROUND/cache/enroot"
    export ENROOT_DATA_PATH="$TEST_PLAYGROUND/data/enroot"
    export ENROOT_TEMP_PATH="$TEST_PLAYGROUND/tmp/enroot"

    SLURM_DEFAULT_PARTITION=$(get_slurm_default_partition)
    export SLURM_DEFAULT_PARTITION
}

function teardown() {
    rm -rf "$TEST_PLAYGROUND"
}

# bats test_tags=serial,skipped-local,slurmalloc
@test "srun --container-image runs in a container (with the right mount options)" {
    on_horeka || skip
    GET_DISTRONAME=(grep PRETTY /etc/os-release)
    
    # Running on the host (on a compute node)
    run srun -p "$SLURM_DEFAULT_PARTITION" \
        -n 1 -t 1 \
        "${GET_DISTRONAME[@]}"

    refute_output --partial "Alpine Linux"

    # From: https://www.nhr.kit.edu/userdocs/horeka/containers/#start-directly-via-pyxis
    # Running inside a container (on a compute node)
    run srun -p "$SLURM_DEFAULT_PARTITION" \
        --container-image=alpine:latest \
        --container-mounts=/etc/slurm/task_prolog:/etc/slurm/task_prolog,/scratch:/scratch,/usr/lib64/slurm/libslurmfull.so,/usr/lib64/libhwloc.so.15 \
        -n 1 -t 1 \
        "${GET_DISTRONAME[@]}"

    if [[  "$status" -ne 0 ]]
    then
        echo "# This test has failed. " >&3
        echo "# This test might fail with any of the following errors: " >&3
        echo "# - 'permission denied'" >&3
        echo "# - 'slurmstepd: error: TaskProlog failed status=127'" >&3
        echo "# - 'slurmstepd: error: pyxis: failed to import docker image'" >&3
        echo "# this is why we do not use pyxis." >&3
    else
        assert_output --partial "Alpine Linux"
    fi
}
