
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
    sleep $((ALLOCATION_MANAGER_CYCLETIME+1))
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

@test "job starts is recorded in logfile" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh
    submit_to_allocation_manager job-123.sh
    rm job-123.sh
    sleep $ALLOCATION_MANAGER_CYCLETIME
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

    touch job-1.sh
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
