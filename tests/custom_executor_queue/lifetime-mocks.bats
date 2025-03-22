#!/usr/bin/env bash

setup(){
    load '../test_helper/bats-file/load'
    load 'common_setup'
    load '../test-utils'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"
    load_mocks

    TEST_PLAYGROUND="$PWD/ce-lifetime-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    WORKDIR="${TEST_PLAYGROUND}"/cews
    STARTDIR="${TEST_PLAYGROUND}"/start

    mkdir -p "$STARTDIR"
    cd "$STARTDIR"

}

teardown(){
    _common_teardown
}

@test "custom_executor_queue_is_alive calls scontrol with the right arguments" {

    (
        SLURM_JOB_ID=987654321
        start_custom_executor_queue "$WORKDIR" 3> /dev/null
    )
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    (
        CUSTOM_EXECUTOR_QUEUE_HOSTNAME=something_else
        # This should trigger the codepath
        # that uses the slurm facilities
        custom_executor_queue_is_alive
    ) 3> /dev/null

    # scontrol was called
    assert_exists "$MOCKLOGDIR/scontrol.log"
    touch "$MOCKLOGDIR/scontrol.log"

    assert_file_contains "$MOCKLOGDIR/scontrol.log" "ARGS: wait_job 987654321"

    stop_custom_executor_queue
    # custom_executor_queue should now be dead
    #refute custom_executor_queue_is_alive

}
