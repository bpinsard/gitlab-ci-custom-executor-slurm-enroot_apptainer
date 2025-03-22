#!/usr/bin/env bash

function has_slurm_and_enroot() {
    type -p srun &> /dev/null && type -p enroot &> /dev/null
}

function get_slurm_default_partition() {
    scontrol show partition | grep -e "dev_\(single\|cpuonly\)" | cut -d= -f2
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

# bats test_tags=serial
@test "srun --container-image runs in a container (with the right mount options)" {
    # Ffrom https://www.nhr.kit.edu/userdocs/horeka/containers/
    on_horeka || skip
    GET_DISTRONAME=(grep PRETTY /etc/os-release)
    
    # Running on the host (on a compute node)
    run srun -p "$SLURM_DEFAULT_PARTITION" \
        -n 1 -t 1 \
        "${GET_DISTRONAME[@]}"

    refute_output --partial "Alpine Linux"

    # Running inside a container (on a compute node)
    run srun -p "$SLURM_DEFAULT_PARTITION" \
        --container-image=alpine:latest \
        --container-mounts=/scratch:/scratch,/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk \
        -n 1 -t 1 \
        "${GET_DISTRONAME[@]}"

    if [[  "$status" -ne 0 ]]
    then
        echo "# This test has failed. " >&3
        echo "# This test might fail with a 'permission denied' error," >&3
        echo "# this is why we to not use pyxis." >&3
        assert_output --partial "permission denied"
    else
        assert_output --partial "Alpine Linux"
    fi
}
