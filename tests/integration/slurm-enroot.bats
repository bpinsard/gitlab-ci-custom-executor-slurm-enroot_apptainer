#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading
    PATH="$PROJECT_ROOT/src:$PATH"

    TEST_PLAYGROUND="$PWD/$(mktemp -d configure-testXXXXXXX)"
    echo "Created test playground at $TEST_PLAYGROUND" >&3
    export ENROOT_RUNTIME_PATH="$TEST_PLAYGROUND/run/enroot"
    export ENROOT_CONFIG_PATH="$TEST_PLAYGROUND/conf/enroot"
    export ENROOT_CACHE_PATH="$TEST_PLAYGROUND/cache/enroot"
    export ENROOT_DATA_PATH="$TEST_PLAYGROUND/data/enroot"
    export ENROOT_TEMP_PATH="$TEST_PLAYGROUND/tmp/enroot"
}

function teardown() {
    rm -rf "$TEST_PLAYGROUND"


}

@test "srun --container-image runs in a container (with the right mount options)" {
    # Ffrom https://www.nhr.kit.edu/userdocs/horeka/containers/
    _on_horeka || skip
    GET_DISTRONAME=(grep PRETTY /etc/os-release)
    
    # Running on the host (on a compute node)
    run srun -p dev_cpuonly \
        -n 1 -t 1 \
        "${GET_DISTRONAME[@]}"

    refute_output --partial "Alpine Linux"

    # Running inside a container (on a compute node)
    run srun -p dev_cpuonly \
        --container-image=alpine:latest \
        --container-mounts=/scratch:/scratch,/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk \
        -n 1 -t 1 \
        "${GET_DISTRONAME[@]}"

    assert_output --partial "Alpine Linux"
}

