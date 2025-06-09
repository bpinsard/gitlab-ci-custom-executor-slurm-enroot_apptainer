#!/usr/bin/env bash

# This is based on the tutorial for bats
# https://bats-core.readthedocs.io/en/stable/tutorial.html

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load'
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    load_mocks

    SRC="$PROJECT_ROOT/src"
    #shellcheck source=./src/configure-slurm-include.sh
    source "$SRC"/configure-slurm-include.sh



    TEST_PLAYGROUND="$PWD/configure-include-test-$BATS_TEST_NAME"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
}


function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
}

@test "copying CUSTOM_ENV_* variables into variables works for defined CUSTOM_ENV_* variables " {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_TESTVARIABLE="avalue"

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    assert [ "$TESTVARIABLE" == "avalue" ]

}

@test "copying CUSTOM_ENV_* variables into variables does nothing for undefined CUSTOM_ENV_* variables " {

    unset CUSTOM_ENV_TESTVARIABLE

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    set +o nounset
    assert [ -z "$TESTVARIABLE" ]
    set -o nounset

}

@test "copying CUSTOM_ENV_* variables into variables and exporting works for defined CUSTOM_ENV_* variables " {

    # shellcheck disable=SC2031
    export CUSTOM_ENV_TESTVARIABLE="avalue"

    export_custom_env_var_into_var_if_defined TESTVARIABLE

    run env

    assert_output --partial "TESTVARIABLE=avalue"


}

@test "check_for_forbidden_options fails when conflicts are present" {

    run check_for_forbidden_option "--propagate=SOMETHING" "--propagate"

    assert_failure
    assert_equal "$status" 22

}

@test "check_for_orbidden_options succeeds when conflicts are NOT present" {

    run check_for_forbidden_option "--partition=" "--propagate"

    assert_success

}

@test "check_string_has_no_forbidden_options fails when bad options used " {
    for OPTION in --propagate --parsable --signal --input --output --error
    do
        echo "Testing $OPTION..."
        run check_string_has_no_forbidden_options "$OPTION"
        assert_failure
    done
}

@test "find_available_workspace_name gives cews_N with N>=0 the smallest so that cews_N does not exist" {

    mkdir "$TEST_PLAYGROUND/cews_0"
    mkdir "$TEST_PLAYGROUND/cews_1"
    touch "$TEST_PLAYGROUND/cews_2"
    run find_available_workspace_name "$TEST_PLAYGROUND/cews_"
    assert_success
    assert_output "$TEST_PLAYGROUND/cews_3"

}

@test "find_available_workspace_name creates new dir" {

    mkdir "$TEST_PLAYGROUND/cews_0"
    mkdir "$TEST_PLAYGROUND/cews_1"
    touch "$TEST_PLAYGROUND/cews_2"
    run find_available_workspace_name "$TEST_PLAYGROUND/cews_"
    assert_output "$TEST_PLAYGROUND/cews_3"
    assert_success
    assert_dir_exists "$TEST_PLAYGROUND/cews_3"

}


@test "find_available_workspace_name errors if stem does not exist" {


    run find_available_workspace_name "$TEST_PLAYGROUND/something/cews_"

    assert_failure
    assert_output "Not an existing directory: $TEST_PLAYGROUND/something"

}

@test "get_slurm_jobid gets the slurm job id from the .env file in the directory given as input" {

    WS="$TEST_PLAYGROUND/cews_something"
    mkdir "$WS"
    SLURM_JOB_ID=34343434
    echo "declare -x CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=$SLURM_JOB_ID" > "$WS"/.env

    run get_slurm_jobid "$WS"
    assert_output "$SLURM_JOB_ID"

}

@test "find_remaining_time_sec_in_allocation of good job gives 600 sec (mock)" {

    SLURM_JOB_ID=34343434 # good, according to the mock
    WS="$TEST_PLAYGROUND/cews_something"
    mkdir "$WS"
    echo "declare -x CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=$SLURM_JOB_ID" > "$WS"/.env


    ALLOCTIME=$(find_remaining_time_sec_in_allocation "$WS")
    assert [ "$ALLOCTIME" -ge 598 ] &&  [ "$ALLOCTIME" -le 602 ]

}

@test "find_remaining_time_sec_in_allocation of completing job gives 0 sec (mock)" {

    SLURM_JOB_ID=45454545 # completing, according to the mock
    WS="$TEST_PLAYGROUND/cews_something"
    mkdir "$WS"
    echo "declare -x CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=$SLURM_JOB_ID" > "$WS"/.env

    run find_remaining_time_sec_in_allocation "$WS"
    assert_output 0

}

@test "find_remaining_time_sec_in_allocation of bad job gives 0 sec (mock)" {

    SLURM_JOB_ID=11111111111 # not among mock's options, invalid job or already terminated
    WS="$TEST_PLAYGROUND/cews_something"
    mkdir "$WS"
    echo "declare -x CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=$SLURM_JOB_ID" > "$WS"/.env

    run find_remaining_time_sec_in_allocation "$WS"
    assert_output 0

}

@test "allocation_is_alive succeeds for a job that is running" {

    SLURM_JOB_ID=34343434 # good, according to the mock
    WS="$TEST_PLAYGROUND/cews_something"
    mkdir "$WS"
    echo "declare -x CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=$SLURM_JOB_ID" > "$WS"/.env


    run allocation_is_alive "$WS"
    assert_success

}

@test "allocation_is_alive fails for a job that is not running" {

    SLURM_JOB_ID=11111111111 # not among mock's options, invalid job or already terminated
    WS="$TEST_PLAYGROUND/cews_something"
    mkdir "$WS"
    echo "declare -x CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=$SLURM_JOB_ID" > "$WS"/.env


    run allocation_is_alive "$WS"
    assert_failure

}

@test "allocation_is_starting succeeds for a workspace that has no .env yet" {

    WS="$TEST_PLAYGROUND/cews_something"
    mkdir "$WS"

    allocation_is_starting "$WS"

}

@test "allocation_is_starting fails for a workspace that has a .env already" {

    WS="$TEST_PLAYGROUND/cews_something"
    mkdir "$WS"
    touch "$WS/.env"


    run allocation_is_starting "$WS"
    assert_failure

}


@test "create_job_slurm - if WALLTIME_SECONDS > 86400, slurm_time_limit_from_seconds should fail" {
    run slurm_time_limit_from_seconds 86401
    assert_failure
    assert_equal "$status" 22 # invalid argument
    assert_output --partial "Error: Walltime Seconds > 1 day"

}

@test "create_job_slurm creates job.slurm in CUSTOM_ENV_CI_WS and returns the location" {

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ciws"
    mkdir "$CUSTOM_ENV_CI_WS"

    CUSTOM_ENV_SLURM_DEFAULT_PARTITION=default_partition_name
    CUSTOM_ENV_JOB_TIME_SEC=1234

    run create_job_slurm "$SRC/job.slurm.template" \
                         "$CUSTOM_ENV_SLURM_DEFAULT_PARTITION" \
                         "$CUSTOM_ENV_JOB_TIME_SEC" \
                         "$CUSTOM_ENV_CI_WS"

    assert_output "$CUSTOM_ENV_CI_WS/job.slurm"
    assert_exists "$CUSTOM_ENV_CI_WS/job.slurm"
    assert_file_contains "$CUSTOM_ENV_CI_WS/job.slurm" default_partition_name
    assert_file_contains "$CUSTOM_ENV_CI_WS/job.slurm" 00:20:34

}

@test "print_json_output_slurm behaves correctly" {

    print_json_output_slurm /some/path/like/this
    function _helper() {
        print_json_output_slurm /some/path/like/this
    }
    run _helper
    assert_output --partial '"builds_dir": "/some/path/like/this"'
    assert_output --partial '"job_env"'

}

@test "print_json_output_noslurm emits correct json" {

    print_json_output_slurm /some/path/like/this | json_validate

}
