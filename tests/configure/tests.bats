#!/usr/bin/env bash
#
function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load'
    load '../test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    load_mocks
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/configure-test-$BATS_TEST_NAME"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export SYSTEM_FAILURE_EXIT_CODE=22

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci-ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42

    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321

    setup_allowed_committers_file

    echo "Test setup phase completed."
}

function teardown() {

    while [ -d "$TEST_PLAYGROUND" ]
    do
        try_to_remove_dir "$TEST_PLAYGROUND" || echo "Failed removal, retrying in one sec..."
        sleep 1
    done

}



@test "allowed committers are checked at the configure stage - failure" {

    # shellcheck disable=SC2030
    export CUSTOM_ENV_GITLAB_USER_LOGIN="SomeoneElse"

    run "$SRC"/configure.sh none noslurm 3> /dev/null

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --partial "SomeoneElse not in allowed committer list."

}

@test "allowed committers are checked at the configure stage - success" {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_GITLAB_USER_LOGIN="Bob"

    "$SRC"/configure.sh none noslurm 3> /dev/null

}

@test "allowed committers are checked at the configure stage - substring failure" {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_GITLAB_USER_LOGIN="Ali"

    run "$SRC"/configure.sh none noslurm 3> /dev/null

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --partial "Ali not in allowed committer list."

}

@test "if CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE not defined, everything ok if GITLAB_USER_LOGIN==USER" {

    unset CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_GITLAB_USER_LOGIN="$USER"

    "$SRC"/configure.sh none noslurm 3> /dev/null

}

@test "if CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE not defined, fail if GITLAB_USER_LOGIN!=USER" {

    unset CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE

    # shellcheck disable=SC2031
    export CUSTOM_ENV_GITLAB_USER_LOGIN="not_$USER"

    run "$SRC"/configure.sh none noslurm 3> /dev/null

    assert_failure
    assert_output --partial "$CUSTOM_ENV_GITLAB is not $USER"
    assert_output --partial "CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE undefined"
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"

}


@test "CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE must have the right permissions and ownership" {


    chmod go+w "$CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE"
    ls -l "$CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE"

    run "$SRC"/configure.sh none noslurm 3> /dev/null

    assert_failure
    assert_output --partial "it should not be writable by anybody"
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"

}
