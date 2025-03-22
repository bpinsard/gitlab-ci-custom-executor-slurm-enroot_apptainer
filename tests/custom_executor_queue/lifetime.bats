#!/usr/bin/env bash

setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    TEST_PLAYGROUND="$PWD/ce-lifetime-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"

    WORKDIR="${TEST_PLAYGROUND}"/cews
    STARTDIR="${TEST_PLAYGROUND}"/start

    mkdir -p "$STARTDIR"
    cd "$STARTDIR"

}

teardown(){
    _common_teardown
}

@test "custom executor queue complains when invoked with the wrong number of arguments" {

    run start_custom_executor_queue many more args than needed 3> /dev/null
    assert_failure

}

@test "custom executor queue starts and is alive - same shell" {
    # We test in the current shell,
    start_custom_executor_queue "${WORKDIR}" 3> /dev/null
    sleep 5
    echo "Jobs:"
    echo "===================="
    jobs -r
    echo "===================="
    job_is_alive=$(jobs -r | wc -l)
    assert_equal "$job_is_alive" 1

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
}

@test "start_custom_executor_queue creates env file" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    assert_file_exists "$WORKDIR"/.env
    # There are 6 variables that need to be declared
    # (this might need to be updated)
    set +o nounset
    if [ -n "$SLURM_JOB_ID" ]
    then
        NVAR=8
    else
        NVAR=7
    fi
    set -o nounset
    assert_equal "$(wc -l < "$WORKDIR"/.env)" "$NVAR"

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
}

@test "sourcing env files gives you CUSTOM_EXECUTOR_QUEUE... variables" {

    assert _no_custom_executor_queue_variables_declared
    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    refute _no_custom_executor_queue_variables_declared

    stop_custom_executor_queue
}

@test "SLURM_JOB_ID saved in .env when available as CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID" {

    (
        export SLURM_JOB_ID=987654321
        start_custom_executor_queue "$WORKDIR" 3> /dev/null
    )
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    assert_equal "$CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID" 987654321
    stop_custom_executor_queue

}

@test "custom executor queue dies when killed" {
    (start_custom_executor_queue "${WORKDIR}" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
    refute ps --pid "$CUSTOM_EXECUTOR_QUEUE_PID" > /dev/null

}


@test "stop_custom_executor_queue stops the custom executor queue" {

    (start_custom_executor_queue "${WORKDIR}" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
    refute ps --pid "$CUSTOM_EXECUTOR_QUEUE_PID" > /dev/null

}

@test "custom_executor_queue_is_alive gives right result" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    assert custom_executor_queue_is_alive

    stop_custom_executor_queue

    # custom_executor_queue should now be dead
    refute custom_executor_queue_is_alive

}


@test "custom executor queue ensures workdir exists" {
    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR/".env
    assert [ -d "${WORKDIR}" ]
    stop_custom_executor_queue
}

@test "cleanup_custom_executor_queue_workspace deletes workspace" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR/".env
    cleanup_custom_executor_queue_workspace
    refute [ -d "$WORKDIR" ]

}

@test "cleanup custom executor queue workspace stops the custom executor queue" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cleanup_custom_executor_queue_workspace
    refute custom_executor_queue_is_alive

}

@test "start_custom_executor_queue creates logfile" {

    LOGFILE="$WORKDIR"/log.txt
    refute [ -f "$LOGFILE" ]

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

    assert_file_exists "$LOGFILE"
    # shellcheck disable=SC1091
    source "$WORKDIR/".env
    stop_custom_executor_queue

}

# bats test_tags=ce_termination
@test "custom executor queue should die gracefully when killed with SIGUSR1 and print a message" {

    LOGFILE="$WORKDIR"/log.txt

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    run cat "$LOGFILE"
    refute_output  --partial "Stopping custom executor queue..."

    wait_until_file_contains "$LOGFILE" "Starting custom executor queue." 20
    kill -s SIGUSR1 "$CUSTOM_EXECUTOR_QUEUE_PID"
    # killing might take a while, but not forever
    declare -i count
    count=0
    while custom_executor_queue_is_alive && [ "$count" -lt 40 ]
    do
        sleep 1
        count=$((count+1))
    done
    if custom_executor_queue_is_alive
    then
        echo "custom executor queue refuses to die"
    fi

    wait_until_file_contains "$LOGFILE" "Stopping custom executor queue..." 20

    assert_file_contains "$LOGFILE" "Stopping custom executor queue..."


}


# bats test_tags=ce_termination
@test "custom executor queue should die gracefully when killed with SIGTERM and print a message" {

    LOGFILE="$WORKDIR"/log.txt

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    run cat "$LOGFILE"
    refute_output  --partial "Stopping custom executor queue..."

    wait_until_file_contains "$LOGFILE" "Starting custom executor queue." 20
    kill -s SIGTERM "$CUSTOM_EXECUTOR_QUEUE_PID"
    # killing might take a while, but not forever
    declare -i count
    count=0
    while custom_executor_queue_is_alive && [ "$count" -lt 40 ]
    do
        sleep 1
        count=$((count+1))
    done

    wait_until_file_contains "$LOGFILE" "Stopping custom executor queue..." 40
    assert_file_contains "$LOGFILE" "Stopping custom executor queue..."


}
