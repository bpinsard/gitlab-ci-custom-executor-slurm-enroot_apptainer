#!/usr/bin/env bash

# This is based on the tutorial for bats
# https://bats-core.readthedocs.io/en/stable/tutorial.html

function setup() {
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    PATH="$PROJECT_ROOT/src:$PATH"
    source include.sh

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

@test "assemble mounts directive works as expected" {

    ARR=(a list of paths)

    run assemble_mounts "${ARR[@]}"

    assert_output "a:a,list:list,of:of,paths:paths"

}

@test "copying custom_env_* variables into variables works for defined custom_env_* variables " {

    export CUSTOM_ENV_TESTVARIABLE="avalue"

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    assert [ "$TESTVARIABLE" == "avalue" ]

}

@test "copying custom_env_* variables into variables does nothing for undefined custom_env_* variables " {

    unset CUSTOM_ENV_TESTVARIABLE

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    assert [ -z "$TESTVARIABLE" ]

}

@test "copying custom_env_* variables into variables and exporting works for defined custom_env_* variables " {

    export CUSTOM_ENV_TESTVARIABLE="avalue"

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    run env

    assert_output --partial "TESTVARIABLE=avalue"


}
