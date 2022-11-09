#!/usr/bin/env bash

setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/allocation_manager.sh"
    WORKDIR="${TEST_PLAYGROUND}"/amws
}

teardown(){
    _common_teardown
}

@test "allocation manager complains when invoked with the wrong number of arguments" {

    refute start_allocation_manager many more args than needed

}

@test "allocation manager starts and is alive - same shell" {
    # We test in the current shell,
    start_allocation_manager "${WORKDIR}"
    sleep 5
    job_is_alive=$(jobs -r | wc -l)
    assert_equal "$job_is_alive" 1

}

@test "start_allocation_manager creates env file" {

    (start_allocation_manager "$WORKDIR")
    assert [ -f "$WORKDIR"/.env ]
    # There are 4 variables that need to be declared
    # (this might need to be updated)
    assert_equal "$(wc -l < "$WORKDIR"/.env)" 4

}

@test "sourcing env files gives you ALLOCATION_MANAGER... variables" {

    assert _no_allocation_manager_variables_declared
    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    echo "sourcing environment..."
    cat "$WORKDIR"/.env
    refute _no_allocation_manager_variables_declared

}

@test "allocation manager dies when killed" {
    (start_allocation_manager "${WORKDIR}")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_allocation_manager
    refute ps --pid $ALLOCATION_MANAGER_JOBID > /dev/null

}


@test "stop_allocation_manager stops the allocation manager" {

    (start_allocation_manager "${WORKDIR}")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_allocation_manager
    refute ps --pid $ALLOCATION_MANAGER_JOBID > /dev/null

}

@test "allocation_manager_is_alive gives right result" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    assert allocation_manager_is_alive

    stop_allocation_manager

    # allocation_manager should now be dead
    refute allocation_manager_is_alive


}

@test "allocation manager ensures workdir exists" {
    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR/".env
    assert [ -d "${WORKDIR}" ]
}

@test "cleanup_allocation_manager_workspace deletes workspace" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR/".env
    cleanup_allocation_manager_workspace
    refute [ -d "$WORKDIR" ]

}

@test "cleanup allocation manager workspace stops the allocation manager" {

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cleanup_allocation_manager_workspace
    refute allocation_manager_is_alive

}

@test "start_allocation_manager creates logfile" {

    LOGFILE="$WORKDIR"/log.txt
    refute [ -f "$LOGFILE" ]

    (start_allocation_manager "$WORKDIR")

    assert [ -f "$LOGFILE" ]

}


@test "allocation manager should die gracefully when killed and print a message" {

    LOGFILE="$WORKDIR"/log.txt

    (start_allocation_manager "$WORKDIR")
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env

    run cat "$LOGFILE"
    refute_output  --partial "Stopping allocation manager..."

    kill -s SIGINT "$ALLOCATION_MANAGER_JOBID"
    # killing might take a while
    while allocation_manager_is_alive
    do
        sleep 1
    done

    run cat "$LOGFILE"
    assert_output  --partial "Stopping allocation manager..."


}
