
setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"
    STARTDIR="${TEST_PLAYGROUND}"/start
    WORKDIR="${TEST_PLAYGROUND}"/cews
    mkdir -p "${STARTDIR}"
    cd "${STARTDIR}"

}

teardown(){
    _common_teardown
}

@test "submitted jobs to custom executor queue get executed" {
    (start_custom_executor_queue  "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat << EOF > job.sh
touch "$TEST_PLAYGROUND"/test-job-results.txt

EOF
    chmod +x job.sh

    submit_to_custom_executor_queue job.sh
    rm job.sh
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 1 1
    assert [ -f  "$TEST_PLAYGROUND"/test-job-results.txt ]
}


@test "submitted jobs to custom executor queue get executed ONCE" {
    (start_custom_executor_queue "$WORKDIR")
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
    nlines=$(wc -l < "$TEST_PLAYGROUND"/test-job-results.txt)

    assert_equal "$nlines" 1
}

@test "job starts are recorded in logfile" {

    (start_custom_executor_queue "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh
    submit_to_custom_executor_queue job-123.sh
    rm job-123.sh
    sleep $CUSTOM_EXECUTOR_QUEUE_CYCLETIME 1
    run cat "$LOGFILE"
    assert_output --regexp "Processing.*job-123.sh"

}

@test "job submission is recorded in logfile" {

    (start_custom_executor_queue "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh

    submit_to_custom_executor_queue job-123.sh
    rm job-123.sh

    sleep 2
    run cat "$LOGFILE"
    assert_output --regexp "Submitted.*job-123.sh"

}

@test "job termination is recorded in job-specific log " {

    (start_custom_executor_queue "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh

    submit_to_custom_executor_queue job-123.sh
    rm job-123.sh
    sleep $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME*2))

    run cat "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/LOGS/job-123.sh.log"
    assert_output --partial "job-123.sh has ended"

}

@test "custom_executor_queue cycles at the given interval" {

    (start_custom_executor_queue "$WORKDIR")
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
    run cat "$LOGFILE"
    assert_output --regexp "Processing.*job-1.sh"


}

@test "job stdout and stderr are both stored in \$WORKSPACE/OUTPUT/<jobfilename>.out" {

    (start_custom_executor_queue "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat << EOF > job-1.sh
echo "A new line"
echo "A stderr line" >&2
EOF

    chmod +x job-1.sh

    submit_to_custom_executor_queue job-1.sh
    rm job-1.sh
    sleep $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME+1))
    assert [ -f "$WORKDIR"/OUTPUT/job-1.sh.out ]

    run cat "$WORKDIR"/OUTPUT/job-1.sh.out
    assert_output - <<EOF
A new line
A stderr line
EOF

}



@test "the exit code of each job should be stored in \$WORKSPACE/OUTPUT/<jobfilename>.exitcode" {

    (start_custom_executor_queue "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat << EOF > job-1.sh
exit 42
EOF

    chmod +x job-1.sh

    submit_to_custom_executor_queue job-1.sh
    rm job-1.sh
    sleep $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME+1))
    assert [ -f "$WORKDIR"/OUTPUT/job-1.sh.exitcode ]

    run cat "$WORKDIR"/OUTPUT/job-1.sh.exitcode
    assert_output "42"

}
@test "custom executor queue should die gracefully when killed and print a message even if a job is running." {

    LOGFILE="$WORKDIR"/log.txt

    (start_custom_executor_queue "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

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

    run cat "$LOGFILE"
    assert_output  --partial "Stopping custom executor queue..."

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

@test "custom executor queue saves the pids of the jobs in a file" {

    (start_custom_executor_queue "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    assert_equal 0 "$( wc -l < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS" )"
    touch job.sh
    chmod +x job.sh

    submit_to_custom_executor_queue job.sh
    sleep $CUSTOM_EXECUTOR_QUEUE_CYCLETIME 1
    assert_equal 1 "$( wc -l < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS" )"
    submit_to_custom_executor_queue job.sh
    sleep $CUSTOM_EXECUTOR_QUEUE_CYCLETIME 1
    assert_equal 2 "$( wc -l < "$CUSTOM_EXECUTOR_QUEUE_JOBPIDS" )"




}


@test "when custom executor queue killed, job termination recorded in job-specific log." {

    LOGFILE="$WORKDIR"/log.txt

    (start_custom_executor_queue "$WORKDIR")
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

    run cat "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/LOGS/job-1.sh.log
    assert_output --partial "job-1.sh was terminated."

}
