#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load'
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    load_mocks

    SRC="$PROJECT_ROOT/src"
    #shellcheck source=./src/configure-noslurm-include.sh
    source "$SRC"/configure-noslurm-include.sh



    TEST_PLAYGROUND="$PWD/configure-include-test-$BATS_TEST_NAME"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
}


function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
}

@test "print_json_output_noslurm behaves correctly" {

    function _helper() {
        print_json_output_noslurm /some/path/like/this
    }
    run _helper
    assert_output --partial '"builds_dir": "/some/path/like/this"'
    refute_output --partial '"job_env"'

}

@test "print_json_output_noslurm emits correct json" {

    print_json_output_noslurm /some/path/like/this | json_validate

}
