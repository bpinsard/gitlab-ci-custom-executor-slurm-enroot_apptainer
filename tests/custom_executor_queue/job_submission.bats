
setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    TEST_PLAYGROUND="$PWD/ce-queue-job-sub-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"


    WORKDIR="${TEST_PLAYGROUND}"/cews
    STARTDIR="${TEST_PLAYGROUND}"/start

    mkdir -p "${STARTDIR}"
    cd "${STARTDIR}" || exit

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

}

teardown(){
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
    _common_teardown
}

@test "submit_to_custom_executor_queue takes job tag as second arg" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job.sh
    echo "Hello"
EOF
    chmod +x job.sh

    run submit_to_custom_executor_queue job.sh JOB-54321
    assert_success

}

@test "submit_to_custom_executor_queue records job name in file called WORKSPACE/TAG" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job-abc.sh
    echo "Hello"
EOF
    chmod +x job-abc.sh

    submit_to_custom_executor_queue job-abc.sh JOB-54321

    assert_exists "$WORKDIR/JOB-54321"
    assert_file_contains "$WORKDIR/JOB-54321" "job-abc.sh"


}

@test "submit_to_custom_executor_queue outputs new file basename (for tracking)" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job-abc.sh
    echo "Hello"
EOF
    chmod +x job-abc.sh

    run submit_to_custom_executor_queue job-abc.sh JOB-54321
    assert_output --regexp 'job-abc.sh-'"$(hostname)"'-[0-9]+-1'

}

@test "job submission is recorded in logfile" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    LOGFILE="$WORKDIR"/log.txt

    touch job-123.sh
    chmod +x job-123.sh

    submit_to_custom_executor_queue job-123.sh JOB-5432
    rm job-123.sh

    wait_until_file_contains "$LOGFILE" "Submitted.*job-123.sh" 30
    assert_file_contains "$LOGFILE" "Submitted.*job-123.sh"

}
# This test is inherently flakier than the others
# when run in a oversubscribed manner.
# bats test_tags=serial
@test "custom_executor_queue cycles at the given interval" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    LOGFILE="$WORKDIR"/log.txt

    touch job-1.sh
    chmod +x job-1.sh
    sleep 1
    # We should miss the first iteration
    submit_to_custom_executor_queue job-1.sh JOB-5432
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
# bats test_tags=serial
@test "attempting to submit many jobs with the same name too fast DOES NOT causes error" {
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
    SUBJOBNAME="job1.sh"
    while [ "$( bash -c 'ls '"$WORKDIR"'/TODO/'"${SUBJOBNAME}"'*' | wc -l )" -lt 10 ]
    do
        TODONAME="$(submit_to_custom_executor_queue job1.sh JOB-5432)"
    done

    submit_to_custom_executor_queue job1.sh JOB-5432


}

@test "submit_to_custom_executor_queue_and_wait blocks until job has executed" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job1.sh
sleep 5
touch $WORKDIR/output
EOF
    chmod +x job1.sh
    run submit_to_custom_executor_queue_and_wait job1.sh JOB-5432
    assert_success
    assert_exists "$WORKDIR/output"

}

@test "submit_to_custom_executor_queue_and_wait blocks until file contains end signal" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job1.sh
sleep 5
touch $WORKDIR/output
EOF
    chmod +x job1.sh
    submit_to_custom_executor_queue_and_wait job1.sh JOB-5432 &

    SLEEP=10
    while ! ls "$WORKDIR/TODO/"* &> /dev/null && [[ "$SLEEP" -gt 0 ]]
    do
        sleep 1
        SLEEP=$((SLEEP-1))
    done
    # Creating DONENAME to trick "submit_to_custom_executor_queue_and_wait"
    touch "$(_donename "$WORKDIR/TODO/job1.sh"*)"
    wait

    assert_exists "$WORKDIR/output"

}
@test "submit_to_custom_executor_queue_and_wait has the same output as the command" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job1.sh
echo this is the output
EOF
    chmod +x job1.sh

    run submit_to_custom_executor_queue_and_wait job1.sh JOB-54321
    assert_output "this is the output"

}

# bats test_tags=exitvalue
@test "submit_to_custom_executor_queue_and_wait has the same exit value as the command" {
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    cat <<EOF > job1.sh
sleep 10
exit 104
EOF
    chmod +x job1.sh
    run submit_to_custom_executor_queue_and_wait job1.sh JOB-5432
    assert_failure
    assert_equal "$status" 104

}

@test "submit_to_custom_executor_queue checks that the CE queue is still running" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue

    cat <<EOF > job.sh
echo "This should not run at all!"
exit 1
EOF
    chmod +x job.sh

    run submit_to_custom_executor_queue job.sh JOB-5432
    assert_failure

    assert_output --partial "ERROR: Custom executor queue process $CUSTOM_EXECUTOR_QUEUE_PID not running!"

}

@test "submit_to_custom_executor_queue returns error and useful error message if no JOBTAG is given" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat <<EOF > job.sh
touch "$TEST_PLAYGROUND/this-should-not-exist"
EOF
    chmod +x job.sh

    run submit_to_custom_executor_queue job.sh
    assert_failure
    assert_output --regexp "Usage: .* script jobtag \[--with-env\]"

    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    assert_not_exist "$TEST_PLAYGROUND/this-should-not-exist"

}


@test "--with-env not mistaken for job tag" {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat <<EOF > job.sh
touch "$TEST_PLAYGROUND/this-should-not-exist"
EOF
    chmod +x job.sh

    run submit_to_custom_executor_queue job.sh --with-env
    assert_failure
    assert_output --regexp "Usage: .* script jobtag \[--with-env\]"

    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    assert_not_exist "$TEST_PLAYGROUND/this-should-not-exist"

}

@test "submit to custom executor queue exits if job script does not exist " {

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    run submit_to_custom_executor_queue unexisting-job.sh job-tag

    assert_failure
    assert_output --regexp "job submission failed: unexisting-job.sh does not exist"


}
