#!/usr/bin/env bash

setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    TEST_PLAYGROUND="$PWD/ce-queue-idle-timer-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"


    WORKDIR="${TEST_PLAYGROUND}"/cews_1
    STARTDIR="${TEST_PLAYGROUND}"/start

    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit


}

teardown(){
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
    _common_teardown
}


# bats test_flags=serial
@test "running jobs that belong to a certain tags are cancelled when requested" {

    (start_custom_executor_queue "$WORKDIR"  3> /dev/null)

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job.sh
sleep 100
EOF

    chmod +x ./job.sh

    TODONAME1="$(submit_to_custom_executor_queue ./job.sh JOB-54321)"
    TODONAME2="$(submit_to_custom_executor_queue ./job.sh JOB-54321)"

    JOBSUBNAME1="$(basename "$TODONAME1")"
    JOBSUBNAME2="$(basename "$TODONAME2")"

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    cancel_job_group JOB-54321

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    #echo "Logfile:"
    #cat "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"

    assert_not_exist "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME1"
    assert_not_exist "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME2"

    # shellcheck disable=SC2012
    assert_equal "$(ls "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME2" | wc -l)" 0

}

@test "cancellation requests put in CANCELLATION_REQUESTS are processed" {

    (start_custom_executor_queue "$WORKDIR"  3> /dev/null)

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job.sh
sleep 100
EOF

    chmod +x ./job.sh

    TODONAME1="$(submit_to_custom_executor_queue ./job.sh JOB-54321)"
    TODONAME2="$(submit_to_custom_executor_queue ./job.sh JOB-54321)"

    JOBSUBNAME1="$(basename "$TODONAME1")"
    JOBSUBNAME2="$(basename "$TODONAME2")"

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    request_cancel_job_group JOB-54321

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    #echo "Logfile:"
    #cat "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"

    assert_not_exist "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME1"
    assert_not_exist "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME2"

    # shellcheck disable=SC2012
    assert_equal "$(ls "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME2" | wc -l)" 0

}


@test "cancellation requests put in CANCELLATION_REQUESTS are processed only once" {

    (start_custom_executor_queue "$WORKDIR"  3> /dev/null)

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job.sh
sleep 100
EOF

    chmod +x ./job.sh

    TODONAME1="$(submit_to_custom_executor_queue ./job.sh JOB-54321)"

    JOBSUBNAME1="$(basename "$TODONAME1")"

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    request_cancel_job_group JOB-54321

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    #echo "Logfile:"
    #cat "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"

    assert_not_exist "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME1"

    TODONAME2="$(submit_to_custom_executor_queue ./job.sh JOB-54321)"

    JOBSUBNAME2="$(basename "$TODONAME2")"

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    assert_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME2"

    # shellcheck disable=SC2012
    assert_equal "$(ls "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME2" | wc -l)" 1

}
