
setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    TEST_PLAYGROUND="$PWD/ce-queue-job-sub-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
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

    submit_to_custom_executor_queue job.sh
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

    submit_to_custom_executor_queue job.sh
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
    submit_to_custom_executor_queue job-123.sh
    rm job-123.sh
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1

    wait_until_file_contains "$LOGFILE" "Processing.*job-123.sh" 30

    assert_file_contains "$LOGFILE" "Processing.*job-123.sh"

}

@test "job submission is recorded in logfile" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh

    submit_to_custom_executor_queue job-123.sh
    rm job-123.sh

    wait_until_file_contains "$LOGFILE" "Submitted.*job-123.sh" 30
    assert_file_contains "$LOGFILE" "Submitted.*job-123.sh"

}

@test "job end is recorded in log " {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh

    submit_to_custom_executor_queue job-123.sh
    rm job-123.sh

    wait_until_file_exists "$LOGFILE" $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME*2))

    wait_until_file_contains "$LOGFILE" "job-123.sh has ended" 30
    assert_file_contains "$LOGFILE" "job-123.sh has ended"

}

# This test is inherently flakier than the others
# when run in a oversubscribed manner.
@test "custom_executor_queue cycles at the given interval" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    LOGFILE="$WORKDIR"/log.txt

    touch job-1.sh
    chmod +x job-1.sh
    sleep 1
    # We should miss the first iteration
    submit_to_custom_executor_queue job-1.sh
    rm job-1.sh
    sleep 1

    run cat "$LOGFILE"
    refute_output --regexp "Processing.*job-1.sh"

    # with a second of margin
    sleep $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME-1-1+1))
    # but now it should have been processed.
    cat "$LOGFILE"
    wait_until_file_contains "$LOGFILE" "Processing.*job-1.sh" 30

    assert_file_contains "$LOGFILE" "Processing.*job-1.sh"


}

@test "job stdout and stderr are both stored in \$WORKSPACE/OUTPUT/<jobfilename>.out" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat << EOF > job-1.sh
echo "A new line"
echo "A stderr line" >&2
EOF

    chmod +x job-1.sh

    submit_to_custom_executor_queue job-1.sh
    rm job-1.sh
    local OUT="$WORKDIR"/OUTPUT/job-1.sh.out
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

    submit_to_custom_executor_queue job-1.sh
    rm job-1.sh
    wait_until_file_exists "$WORKDIR"/OUTPUT/job-1.sh.exitcode 30
    assert_file_exists "$WORKDIR"/OUTPUT/job-1.sh.exitcode

    assert_file_contains "$WORKDIR"/OUTPUT/job-1.sh.exitcode "42"

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

    submit_to_custom_executor_queue job-1.sh
    rm job-1.sh
    sleep $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME+1))

    kill -s SIGTERM "$CUSTOM_EXECUTOR_QUEUE_JOBID"
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

# bats test_tags=samename,serialization,serial
@test "execution of jobs with the same name is serialized." {
    # This is a stronger test when run in serial

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    assert_equal 0 "$( wc -l < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS" )"

    cat <<EOF > job.sh
# So that it will take long enough
for i in {1..5}
do
    sleep $CUSTOM_EXECUTOR_QUEUE_CYCLETIME
done
EOF
    chmod +x job.sh
    submit_to_custom_executor_queue job.sh
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1

    cat <<EOF > job.sh
# I am an unfortunate job.
touch "$WORKDIR/result.out"
EOF
    submit_to_custom_executor_queue job.sh || exit
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1
    # job.sh MUST NOT have executed
    assert_file_not_exists "$WORKDIR/result.out"

    # But after the first job has completed, the second one should be executed.
    sleep "$((8*CUSTOM_EXECUTOR_QUEUE_CYCLETIME))"

    assert_file_exists "$WORKDIR/result.out"


}

# bats test_tags=failing
@test "custom executor queue saves the pids of the jobs in a file" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    assert_equal 0 "$( wc -l < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS" )"

    touch job1.sh
    chmod +x job1.sh
    submit_to_custom_executor_queue job1.sh
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1
    assert_equal 1 "$( wc -l < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS" )"

    submit_to_custom_executor_queue job1.sh
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1
    assert_equal 2 "$( wc -l < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS" )"

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

    submit_to_custom_executor_queue job-1.sh
    rm job-1.sh
    sleep $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME+1))

    kill -s SIGTERM "$CUSTOM_EXECUTOR_QUEUE_JOBID"
    # killing might take a while
    while custom_executor_queue_is_alive
    do
        sleep 1
    done

    # killing subprocesses might take a while
    while read -r CHILD_PID
    do
        while ps --pid "$CHILD_PID" > /dev/null
        do
            echo "waiting for $CHILD_PID to end."
            sleep 1
        done
    done < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS"

    assert_file_contains "$LOGFILE" "job-1.sh was terminated."

}

# bats test_tags=samename,serial
@test "attempting to submit 2 jobs with the same name too fast causes error" {
# Using serial here because this test might fail
# if there is too much congestion:
# the first script might be snatched
# before we manage to try to submit the second.

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job1.sh
echo "A line of output"
EOF
    chmod +x job1.sh
    while [ ! -f "$WORKDIR"/TODO/job1.sh ]
    do
        submit_to_custom_executor_queue job1.sh
    done

    if [ ! -f "$WORKDIR"/TODO/job1.sh ]
    then
        skip # We are very unlucky
    fi
    run submit_to_custom_executor_queue job1.sh
    assert_equal "$status" 22


}

# bats test_tags=blocking
@test "submit_to_custom_executor_queue_and_wait blocks until job has executed" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job1.sh
sleep 5
touch $WORKDIR/output
EOF
    chmod +x job1.sh
    run submit_to_custom_executor_queue_and_wait job1.sh
    assert_success

    assert_exists "$WORKDIR/output"

}


# bats test_tags=output
@test "submit_to_custom_executor_queue_and_wait has the same output as the command" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job1.sh
echo this is the output
EOF
    chmod +x job1.sh
    run submit_to_custom_executor_queue_and_wait job1.sh
    assert_output "this is the output"

}

# bats test_tags=exitvalue
@test "submit_to_custom_executor_queue_and_wait has the same exit value as the command" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job1.sh
exit 104
EOF
    chmod +x job1.sh
    run submit_to_custom_executor_queue_and_wait job1.sh
    assert_equal "$status" 104


}

# bats test_tags=location
@test "submitted script is executed in the same directory it was submitted" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    mkdir somewhere
    cat <<EOF > somewhere/job.sh
touch a-file-here
EOF
    chmod +x somewhere/job.sh

    cd somewhere
    run submit_to_custom_executor_queue_and_wait job.sh
    assert_exists a-file-here


}

# bats test_tags=thisone
@test "submit_to_custom_executor_queue checks that the job is still running" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue

    cat <<EOF > job.sh
echo "This should not run at all!"
exit 1
EOF
    chmod +x job.sh

    run submit_to_custom_executor_queue job.sh
    assert_failure

    assert_output "ERROR: Custom executor queue process $CUSTOM_EXECUTOR_QUEUE_JOBID not running!"

}
