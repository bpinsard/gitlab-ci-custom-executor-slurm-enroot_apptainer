#!/usr/bin/env bash

# This is based on the tutorial for bats
# https://bats-core.readthedocs.io/en/stable/tutorial.html

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    SRC="$PROJECT_ROOT/src"
    # shellcheck disable=SC1091
    source "$SRC"/configure-slurm-include.sh

    TEST_PLAYGROUND="$PWD/configure-slurm-include-test-$BATS_TEST_NAME"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
}


function teardown() {
    rm -r "$TEST_PLAYGROUND"
}

@test "copying CUSTOM_ENV_* variables into variables works for defined CUSTOM_ENV_* variables " {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_TESTVARIABLE="avalue"

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    assert [ "$TESTVARIABLE" == "avalue" ]

}

@test "copying CUSTOM_ENV_* variables into variables does nothing for undefined CUSTOM_ENV_* variables " {

    unset CUSTOM_ENV_TESTVARIABLE

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    set +o nounset
    assert [ -z "$TESTVARIABLE" ]
    set -o nounset

}

@test "copying CUSTOM_ENV_* variables into variables and exporting works for defined CUSTOM_ENV_* variables " {

    # shellcheck disable=SC2031
    export CUSTOM_ENV_TESTVARIABLE="avalue"

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    run env

    assert_output --partial "TESTVARIABLE=avalue"


}

@test "check_for_forbidden_options fails when conflicts are present" {

    run check_for_forbidden_option "--propagate=SOMETHING" "--propagate"

    assert_failure
    assert_equal "$status" 22

}

@test "check_for_orbidden_options succeeds when conflicts are NOT present" {

    run check_for_forbidden_option "--partition=dev_cpuonly" "--propagate"

    assert_success

}

@test "check_string_has_no_forbidden_options fails when bad options used " {
    for OPTION in --propagate --parsable --signal --input --output --error
    do
        run check_string_has_no_forbidden_options "$OPTION"
        assert_failure
    done
}
