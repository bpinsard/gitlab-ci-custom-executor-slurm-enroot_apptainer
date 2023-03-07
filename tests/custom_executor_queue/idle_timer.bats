#!/usr/bin/env zsh

setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    TEST_PLAYGROUND="$PWD/ce-queue-idle-timer-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"


    WORKDIR="${TEST_PLAYGROUND}"/cews
    STARTDIR="${TEST_PLAYGROUND}"/start

    mkdir -p "${STARTDIR}"
    cd "${STARTDIR}"


}

teardown(){
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
    _common_teardown
}

# bats test_tags=serial
@test "last activity file created at WORKDIR/last_activity" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    wait_until_file_exists "$WORKDIR/last_activity" 2
    assert_exists "$WORKDIR/last_activity"

}

# bats test_tags=serial
@test "last activity file does not update when work does not happen" {


    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    wait_until_file_exists "$WORKDIR/last_activity" 2

    TIME1=$(cat "$WORKDIR/last_activity")

    source "$WORKDIR"/.env

    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"

    TIME2=$(cat "$WORKDIR/last_activity")

    assert_equal "$TIME2" "$TIME1"

}


# bats test_tags=serial
@test "last activity file updates when work happens" {


    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    wait_until_file_exists "$WORKDIR/last_activity" 2

    TIME1=$(cat "$WORKDIR/last_activity")

    cat <<EOF > job.sh
sleep 20
EOF

    chmod +x ./job.sh
    source "$WORKDIR"/.env
    submit_to_custom_executor_queue ./job.sh

    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"

    TIME2=$(cat "$WORKDIR/last_activity")

    cat "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"
    assert_not_equal "$TIME2" "$TIME1"

}

#bats test_tags=onlythis
@test "after a given idle time, the custom executor queue stops running" {

    export IDLE_TIME_SEC=10
    (start_custom_executor_queue "$WORKDIR"  3> /dev/null)

    source "$WORKDIR"/.env
    assert custom_executor_queue_is_alive

    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep $IDLE_TIME_SEC
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"

    refute custom_executor_queue_is_alive

}
