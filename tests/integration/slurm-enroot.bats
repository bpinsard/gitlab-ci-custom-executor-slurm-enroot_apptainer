#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading
    PATH="$PROJECT_ROOT/src:$PATH"

}

function _on_horeka () {
    hostname | grep -q -E "hkn[0-9]{4}.localdomain"
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

