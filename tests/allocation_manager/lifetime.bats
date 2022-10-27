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

@test "allocation manager starts and is alive - same shell" {
    # We test in the current shell,
    start_allocation_manager 2 1 "${WORKDIR}"
    sleep 1
    job_is_alive=$(jobs -r | wc -l)
    assert_equal $job_is_alive 1

}

@test "start_allocation_manager creates env file" {

    (start_allocation_manager 1 1 $WORKDIR)
    assert [ -f $WORKDIR/.env ]
    # There are 4 variables that need to be declared
    # (this might need to be updated)
    assert_equal $(cat $WORKDIR/.env | wc -l) 5

}

@test "sourcing env files gives you ALLOCATION_MANAGER... variables" {

    assert _no_allocation_manager_variables_declared
    (start_allocation_manager 1 1 $WORKDIR)
    source $WORKDIR/.env
    echo "sourcing environment..."
    cat $WORKDIR/.env
    refute _no_allocation_manager_variables_declared

}
@test "allocation_manager_is_alive gives right result" {

    (start_allocation_manager 2 1 $WORKDIR)
    source $WORKDIR/.env
    assert allocation_manager_is_alive
    sleep 3
    # allocation_manager should now be dead
    refute allocation_manager_is_alive


}

@test "allocation manager dies after worktime" {
    (start_allocation_manager 2 1 "${WORKDIR}")
    source $WORKDIR/.env
    sleep 3
    refute allocation_manager_is_alive
}

@test "stop_allocation_manager stops the allocation manager" {

    (start_allocation_manager 5 1 "${WORKDIR}")
    source $WORKDIR/.env
    stop_allocation_manager
    refute allocation_manager_is_alive

}

@test "allocation manager ensures workdir exists" {
    (start_allocation_manager 1 1 $WORKDIR)
    source $WORKDIR/.env
    assert [ -d "${WORKDIR}" ]
}

@test "cleanup_allocation_manager_workspace deletes workspace" {

    (start_allocation_manager 1 1 $WORKDIR)
    source $WORKDIR/.env
    cleanup_allocation_manager_workspace
    refute [ -d $WORKDIR ]

}

@test "cleanup allocation manager workspace stops the allocation manager" {

    (start_allocation_manager 10 1 $WORKDIR)
    source $WORKDIR/.env
    cleanup_allocation_manager_workspace
    refute allocation_manager_is_alive

}

@test "start_allocation_manager creates logfile" {

    LOGFILE=$WORKDIR/log.txt
    refute [ -f "${LOGFILE}" ]

    (start_allocation_manager 1 1 $WORKDIR)

    assert [ -f "${LOGFILE}" ]

}

