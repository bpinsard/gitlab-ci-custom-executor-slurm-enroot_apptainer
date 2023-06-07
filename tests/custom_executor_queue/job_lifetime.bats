#!/usr/bin/env bash

setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    TEST_PLAYGROUND="$PWD/ce-queue-job-sub-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3

    rm -rf "$TEST_PLAYGROUND"
    mkdir "$TEST_PLAYGROUND"

    WORKDIR="${TEST_PLAYGROUND}"/cews
    STARTDIR="${TEST_PLAYGROUND}"/start

    mkdir -p "${STARTDIR}"
    cd "${STARTDIR}"

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

}

teardown(){
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
    _common_teardown
}

@test "submitted jobs to custom executor queue get executed" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat << EOF > job.sh
touch "$TEST_PLAYGROUND"/test-job-results.txt

EOF
    chmod +x job.sh

    submit_to_custom_executor_queue job.sh JOB-5432
    rm job.sh
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1 1

    local RESULT

    RESULT="$TEST_PLAYGROUND"/test-job-results.txt
    wait_until_file_exists "$RESULT" 20

    assert_file_exists "$RESULT"
}

@test "submitted jobs to custom executor queue get executed ONCE" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat << EOF > job.sh
echo "A new line" >> $TEST_PLAYGROUND/test-job-results.txt

EOF
    chmod +x job.sh

    submit_to_custom_executor_queue job.sh JOB-5432
    rm job.sh
    # We wait 2 cycle times
    sleep $((2*CUSTOM_EXECUTOR_QUEUE_CYCLETIME))
    local RESULT
    RESULT="$TEST_PLAYGROUND"/test-job-results.txt
    wait_until_file_exists "$RESULT" 20
    nlines=$(wc -l < "$RESULT")
    assert_equal "$nlines" 1
}

@test "job starts are recorded in logfile" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh
    submit_to_custom_executor_queue job-123.sh JOB-5432
    rm job-123.sh
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1

    wait_until_file_contains "$LOGFILE" "Processing.*job-123.sh" 30

    assert_file_contains "$LOGFILE" "Processing.*job-123.sh"

}


@test "job end is recorded in log " {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh

    TODONAME="$(submit_to_custom_executor_queue job-123.sh JOB-5432)"
    rm job-123.sh

    wait_until_file_exists "$LOGFILE" $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME*2))
    SUBJOBNAME="$(basename "$TODONAME")"

    wait_until_file_contains "$LOGFILE" "$SUBJOBNAME has ended" 30
    assert_file_contains "$LOGFILE" "$SUBJOBNAME has ended"

}

@test "job stdout and stderr are both stored in \$WORKSPACE/OUTPUT/<jobfilename>-??.out" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat << EOF > job-1.sh
echo "A new line"
echo "A stderr line" >&2
EOF

    chmod +x job-1.sh

    TODONAME="$(submit_to_custom_executor_queue job-1.sh JOB-5432)"
    rm job-1.sh
    SUBJOBNAME="$(basename "$TODONAME")"
    local OUT="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/OUTPUT/$SUBJOBNAME".out
    wait_until_file_exists "$OUT" 10
    assert_file_exists "$OUT"

    run cat "$OUT"
    assert_output - <<EOF
A new line
A stderr line
EOF

}


@test "the exit code of each job should be stored in \$WORKSPACE/OUTPUT/<jobfilename>.exitcode" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat << EOF > job-1.sh
exit 42
EOF

    chmod +x job-1.sh

    TODONAME="$(submit_to_custom_executor_queue job-1.sh JOB-5432)"
    rm job-1.sh
    SUBJOBNAME="$(basename "$TODONAME")"
    local EXITCODE="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/OUTPUT/$SUBJOBNAME".exitcode
    wait_until_file_exists "$EXITCODE" 30
    assert_file_exists "$EXITCODE"

    assert_file_contains "$EXITCODE" "42"

}
# bats test_tags=location
@test "submitted script is executed in the same directory it was submitted" {
    # This might actually not be needed and potentially harmful
    # in the context of the CI custom executor
    echo "# Skipping this test - we are not sure whether this is needed or not " >&3
    skip

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    mkdir somewhere
    cat <<EOF > somewhere/job.sh
touch a-file-here
EOF
    chmod +x somewhere/job.sh

    cd somewhere
    run submit_to_custom_executor_queue_and_wait job.sh JOB-5432
    assert_exists a-file-here


}

@test "when custom executor queue killed, job termination recorded in log." {

    LOGFILE="$WORKDIR"/log.txt

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat << EOF > job-1.sh
    for i in {1..10}
    do
        sleep 1
    done
EOF

    chmod +x job-1.sh

    TODONAME="$(submit_to_custom_executor_queue job-1.sh JOB-5432)"
    rm job-1.sh
    sleep $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME+1))

    kill -s SIGTERM "$CUSTOM_EXECUTOR_QUEUE_PID"
    # killing might take a while
    while custom_executor_queue_is_alive
    do
        sleep 1
    done

    # killing subprocesses might take a while
    shopt -s nullglob
    for PIDFILE in "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS/*
    do
        read -r CHILD_PID < "$PIDFILE"
        while ps --pid "$CHILD_PID" > /dev/null
        do
            echo "waiting for $CHILD_PID to end."
            sleep 1
        done
    done
    SUBJOBNAME="$(basename "$TODONAME")"

    assert_file_contains "$LOGFILE" "$SUBJOBNAME was terminated."

}

@test "custom executor queue should die gracefully when killed and print a message even if a job is running." {

    LOGFILE="$WORKDIR"/log.txt

    wait_until_file_exists "$WORKDIR/.env" 30
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    wait_until_file_exists "$LOGFILE" 30
    run cat "$LOGFILE"
    refute_output  --partial "Stopping custom executor queue..."

    cat << EOF > job-1.sh
    sleep 10
EOF

    chmod +x job-1.sh

    submit_to_custom_executor_queue job-1.sh JOB-5432
    rm job-1.sh
    sleep $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME+1))

    kill -s SIGTERM "$CUSTOM_EXECUTOR_QUEUE_PID"
    # killing might take a while
    # but should not take 10 seconds,
    # the submitted job should die as well


    while custom_executor_queue_is_alive
    do
        sleep 1
    done

    wait_until_file_contains "$LOGFILE" "Stopping custom executor queue..." 30
    assert_file_contains "$LOGFILE" "Stopping custom executor queue..."

}

@test "listing all the child pids works as expected" {

    for _ in {1..20}
    do
        sleep 10 &
    done

    # There are 20 processes
    # Note: using pipes would break the test
    # for some strange reason.
    echo "All jobs:"
    echo "==================="
    jobs -p
    echo "==================="
    list_all_child_pids > pids
    N=$(wc -l < pids)
    assert_equal "$N" 20

    for line in {1..20}
    do
        function _helper(){
        head -n "$line" pids | tail -n 1
        }

        run _helper

        assert_output --regexp "^[0-9]+$"

    done


}

# bats test_tags=serial
@test "custom executor queue saves the pid of the each job in a separate file" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    assert_equal "$(find "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS -type f | wc -l )" 0

    cat <<EOF > job1.sh
    sleep  "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep  "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
EOF
    chmod +x job1.sh
    submit_to_custom_executor_queue job1.sh JOB-5432
    cp job1.sh job2.sh
    submit_to_custom_executor_queue job2.sh JOB-5432

    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1

    assert_equal "$(find "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS -type f | wc -l )" 2

}

@test "when a script ends, his pid is removed from the PIDS directory" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    assert_equal "$(find "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS -type f | wc -l )" 0

    cat <<EOF > job1.sh
    sleep  "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep  "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep  "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep  "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
EOF
    chmod +x job1.sh

    cat <<EOF > job2.sh
    sleep  "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep  "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
EOF
    chmod +x job2.sh

    submit_to_custom_executor_queue job1.sh JOB-5432
    submit_to_custom_executor_queue job2.sh JOB-5432

    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1

    echo "PIds after submission:"
    ls "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS
    echo "pids count:"
    find "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS -type f | wc -l

    assert_equal "$(find "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS -type f | wc -l )" 2

    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME"

    echo "PIds after a while:"
    ls "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS
    echo "pids count:"
    find "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS -type f | wc -l

    assert_equal "$(find "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/PIDS -type f | wc -l )" 1

}
