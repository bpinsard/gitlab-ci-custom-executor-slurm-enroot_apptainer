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

@test "allocation manager starts and is alive" {
    (start_allocation_manager 2 "${WORKDIR}")
    sleep 1
    job_is_alive=$(jobs -r | wc -l)
    assert_equal $job_is_alive 1

}

@test "allocation manager dies after worktime" {
    start_allocation_manager 1 "${WORKDIR}"
    sleep 2
    job_is_alive=$(jobs -r | wc -l)
    assert_equal $job_is_alive 0
}

@test "stop_allocation_manager stops the allocation manager" {

    start_allocation_manager 5 "${WORKDIR}"
    stop_allocation_manager
    sleep 1 # To give time to the kill to take effect
    job_is_alive=$(jobs -r | wc -l)
    assert_equal $job_is_alive 0

}

@test "allocation manager ensures workdir exists" {
    start_allocation_manager 1 $WORKDIR
    assert [ -d "${WORKDIR}" ]
}

@test "cleanup_allocation_manager_workspace deletes workspace" {

    start_allocation_manager 1 $WORKDIR
    cleanup_allocation_manager_workspace
    refute [ -d $WORKDIR ]

}

@test "cleanup allocation manager workspace stops the allocation manager" {

    start_allocation_manager 10 $WORKDIR
    cleanup_allocation_manager_workspace
    job_is_alive=$(jobs -r | wc -l)
    assert_equal $job_is_alive 0

}

@test "start_allocation_manager creates logfile" {

    LOGFILE=$WORKDIR/log.txt
    refute [ -f "${LOGFILE}" ]

    start_allocation_manager 1 $WORKDIR

    assert [ -f "${LOGFILE}" ]

}

@test "start_allocation_manager creates env file" {

    start_allocation_manager 1 $WORKDIR
    assert [ -f $WORKDIR/.env ]
    assert_equal $(cat $WORKDIR/.env | wc -l) 4

}
