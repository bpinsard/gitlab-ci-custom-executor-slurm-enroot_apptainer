
setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/allocation_manager.sh"
    STARTDIR="${TEST_PLAYGROUND}"/start
    WORKDIR="${TEST_PLAYGROUND}"/amws
    mkdir -p "${STARTDIR}"
    cd "${STARTDIR}"

}

teardown(){
    _common_teardown
}

@test "submitted jobs to allocation manager get executed" {
    (start_allocation_manager  "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat << EOF > job.sh
touch "$TEST_PLAYGROUND"/test-job-results.txt

EOF
    chmod +x job.sh

    submit_to_allocation_manager job.sh
    rm job.sh
    sleep "$ALLOCATION_MANAGER_CYCLETIME" 1 1
    assert [ -f  "$TEST_PLAYGROUND"/test-job-results.txt ]
}


@test "submitted jobs to allocation manager get executed ONCE" {
    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat << EOF > job.sh
echo "A new line" >> $TEST_PLAYGROUND/test-job-results.txt

EOF
    chmod +x job.sh

    submit_to_allocation_manager job.sh
    rm job.sh
    # We wait 2 cycle times
    sleep $((2*ALLOCATION_MANAGER_CYCLETIME))
    nlines=$(wc -l < "$TEST_PLAYGROUND"/test-job-results.txt)

    assert_equal "$nlines" 1
}

@test "job starts are recorded in logfile" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh
    submit_to_allocation_manager job-123.sh
    rm job-123.sh
    sleep $ALLOCATION_MANAGER_CYCLETIME 1
    run cat "$LOGFILE"
    assert_output --regexp "Processing.*job-123.sh"

}

@test "job submission is recorded in logfile" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh

    submit_to_allocation_manager job-123.sh
    rm job-123.sh

    sleep 2
    run cat "$LOGFILE"
    assert_output --regexp "Submitted.*job-123.sh"

}

@test "job termination is recorded in logfile" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh

    submit_to_allocation_manager job-123.sh
    rm job-123.sh
    sleep $((ALLOCATION_MANAGER_CYCLETIME*2))
    run  cat "$LOGFILE"
    assert_output --partial "job-123.sh has ended"

}

@test "allocation_manager cycles at the given interval" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    LOGFILE="$WORKDIR"/log.txt

    touch job-1.sh
    chmod +x job-1.sh
    sleep 1
    # We should miss the first iteration
    submit_to_allocation_manager job-1.sh
    rm job-1.sh
    sleep 1

    run cat "$LOGFILE"
    refute_output --regexp "Processing.*job-1.sh"

    # with a second of margin
    sleep $((ALLOCATION_MANAGER_CYCLETIME-1-1+1))
    # but now it should have been processed.
    cat "$LOGFILE"
    run cat "$LOGFILE"
    assert_output --regexp "Processing.*job-1.sh"


}

@test "job stdout and stderr are both stored in \$WORKSPACE/OUTPUT/<jobfilename>.out" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat << EOF > job-1.sh
echo "A new line"
echo "A stderr line" >&2
EOF

    chmod +x job-1.sh

    submit_to_allocation_manager job-1.sh
    rm job-1.sh
    sleep $((ALLOCATION_MANAGER_CYCLETIME+1))
    assert [ -f "$WORKDIR"/OUTPUT/job-1.sh.out ]

    run cat "$WORKDIR"/OUTPUT/job-1.sh.out
    assert_output - <<EOF
A new line
A stderr line
EOF

}


@test "allocation manager should die gracefully when killed and print a message even if a job is running." {

    LOGFILE="$WORKDIR"/log.txt

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    run cat "$LOGFILE"
    refute_output  --partial "Stopping allocation manager..."

    cat << EOF > job-1.sh
    sleep 10
EOF

    chmod +x job-1.sh

    submit_to_allocation_manager job-1.sh
    rm job-1.sh
    sleep $((ALLOCATION_MANAGER_CYCLETIME+1))

    kill -s SIGTERM "$ALLOCATION_MANAGER_JOBID"
    # killing might take a while
    # but should not take 10 seconds,
    # the submitted job should die as well


    while allocation_manager_is_alive
    do
        sleep 1
    done

    run cat "$LOGFILE"
    assert_output  --partial "Stopping allocation manager..."

}

@test "listing all the child pids works as expected" {

    for I in {1..20}
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

@test "allocation manager saves the pids of the jobs in a file" {

    (start_allocation_manager "$WORKDIR")
    source "$WORKDIR"/.env

    assert_equal 0 $( wc -l < "$ALLOCATION_MANAGER_JOBPIDS" )
    touch job.sh
    chmod +x job.sh

    submit_to_allocation_manager job.sh
    sleep $ALLOCATION_MANAGER_CYCLETIME 1
    assert_equal 1 $( wc -l < "$ALLOCATION_MANAGER_JOBPIDS" )
    submit_to_allocation_manager job.sh
    sleep $ALLOCATION_MANAGER_CYCLETIME 1
    assert_equal 2 $( wc -l < "$ALLOCATION_MANAGER_JOBPIDS" )




}


@test "when allocation manager is killed, the running job should say it was terminated." {

    LOGFILE="$WORKDIR"/log.txt

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat << EOF > job-1.sh
    for i in {1..10}
    do
        sleep 1
    done
EOF

    chmod +x job-1.sh

    submit_to_allocation_manager job-1.sh
    rm job-1.sh
    sleep $((ALLOCATION_MANAGER_CYCLETIME+1))

    kill -s SIGTERM "$ALLOCATION_MANAGER_JOBID"
    # killing might take a while
    while allocation_manager_is_alive
    do
        sleep 1
    done

    # killing subprocesses might take a while
    while read CHILD_PID
    do
        while ps --pid "$CHILD_PID" > /dev/null
        do
            echo "waiting for $CHILD_PID to end."
            sleep 1
        done
    done < "$ALLOCATION_MANAGER_JOBPIDS"


    run cat "$LOGFILE"
    assert_output --partial "job-1.sh was terminated."

}
