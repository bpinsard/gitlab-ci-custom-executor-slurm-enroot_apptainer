#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading
    PATH="$PROJECT_ROOT/src:$PATH"
    TEST_PLAYGROUND=$(mktemp -d alloc-manager-testXXXXXXX)
    echo "Created test playground at $TEST_PLAYGROUND"

    assert _on_horeka
}

function _on_horeka () {
    run hostname
    assert_output --regexp "hkn[0-9]{4}.localdomain"
}


@test "srun --container-image runs in a container (with the right mount options)" {
    # Ffrom https://www.nhr.kit.edu/userdocs/horeka/containers/
    GET_DISTRONAME=(grep PRETTY /etc/os-release)
    run "${GET_DISTRONAME[@]}"
    refute_output --partial "Alpine Linux"

    run srun -p dev_cpuonly \
        --container-image=alpine:latest \
        --container-mounts=/scratch:/scratch,/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk \
        -n 1 -t 1 \
        "${GET_DISTRONAME[@]}"

    assert_output --partial "Alpine Linux"
}
