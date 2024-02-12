#!/usr/bin/env bash

function setup(){
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    load './test_helper/bats-file/load' # for assert_output and refute_output
    load './doc-test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"
    SRC="$PROJECT_ROOT/src"
    README="$PROJECT_ROOT/README.md"
}

@test "README.md exists" {

    assert_exist "$README"

}


@test "default slurm allocation is 600 seconds" {

    # Test the readme
    grep -ni "If the variable is not set, it is assumed" "$README"
    grep -ni "that the job takes 600 seconds." "$README"

    # Test the code
    # shellcheck disable=SC2016
    grep -n 'CUSTOM_ENV_JOB_TIME_SEC="${CUSTOM_ENV_JOB_TIME_SEC:-600}"' "$SRC"/configure*.sh

}

@test "slurm allocation not reused if REUSE_WORKSPACE=OFF " {
    grep_between "Slurm allocation settings" "##" '.*' "$README"


    # Test the readme
    grep_between "Slurm allocation settings" "##" -ni "allocation is not reused" "$README"
    # shellcheck disable=SC2016
    grep_between "Slurm allocation settings" "##" -ni 'if.*`REUSE_WORKSPACE`.*`OFF`' "$README"


    # Test the code
    # shellcheck disable=SC2016
    grep 'if \[ "${CUSTOM_ENV_REUSE_WORKSPACE:-ON}" == "OFF" \]' "$SRC"/configure.sh

}
