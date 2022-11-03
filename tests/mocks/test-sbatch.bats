#!/usr/bin/env bash

setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    WORKDIR="${TEST_PLAYGROUND}"/amws
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PROJECT_ROOT/src/slurm-utils:$PATH"
    TEST_PLAYGROUND=$(mktemp -d alloc-manager-testXXXXXXX)
    echo "Created test playground at $TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND


}

teardown(){
    rm -r $TEST_PLAYGROUND
}

@test "sbatch mock complains if no log location is given" {

    (
    export MOCKLOGDIR=
    refute sbatch something
    )

}

@test "sbatch mock records logs at a given location" {

    sbatch something
    assert [ -f $MOCKLOGDIR/sbatch.log ]

}

@test "sbatch mock records arguments correctly" {

    sbatch something like this
    run cat $MOCKLOGDIR/sbatch.log
    assert_output --partial "something like this"

}

@test "sbatch mock records SBATCH-related environment variables in log" {

    (
    export SBATCH_GPUS=volta:3
    sbatch something like this
    )
    run cat $MOCKLOGDIR/sbatch.log
    assert_output --partial "SBATCH_GPUS=volta:3"
}

@test "sbatch mock records ONLY SBATCH-related environment variables in the proper list" {

    (
    # Unfortunately this is not one of the sbatch input environment variables.
    export SLURM_NTASKS=5
    sbatch something like this
    )
    run cat $MOCKLOGDIR/sbatch.log
    refute_output --partial "SLURM_NTASKS=5"

}

@test "sbatch input environment variables read from docs are the expected ones" {

   source sbatch-input-variable-list.sh
   mapfile INPUT_VARIABLES_FROM_DOCS < <(_get-sbatch-input-env-list.sh)
   N=$(echo ${INPUT_VARIABLES[@]} ${INPUT_VARIABLES_FROM_DOCS[@]} | tr ' ' '\n' | sort | uniq -u | wc -l )
   assert_equal "$N" 0


}
