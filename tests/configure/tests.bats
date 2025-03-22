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
    export CUSTOM_ENV_CI_JOB_TOKEN=""
    export CUSTOM_ENV_CI_API_V4_URL=""

    setup_allowed_gitlab_users_file

    echo "Test setup phase completed."
}

function teardown() {

    while [ -d "$TEST_PLAYGROUND" ]
    do
        try_to_remove_dir "$TEST_PLAYGROUND" || echo "Failed removal, retrying in one sec..."
        sleep 1
    done

}

@test "allowed gitlab users are checked at the configure stage - failure" {

    # shellcheck disable=SC2030
    echo "Alice" > "$ALLOWED_GITLAB_USERS_FILE"

    run "$SRC"/configure.sh none noslurm "$ALLOWED_GITLAB_USERS_FILE" 3> /dev/null

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    # some.one configured in the mock of curl
    assert_output --partial "some.one not in allowed gitlab user list."

}

@test "allowed gitlab users are checked at the configure stage - success" {

    # some.one configured in the mock of curl
    echo "some.one" > "$ALLOWED_GITLAB_USERS_FILE"
    # shellcheck disable=SC2030,SC2031
    "$SRC"/configure.sh none noslurm "$ALLOWED_GITLAB_USERS_FILE" 3> /dev/null

}

@test "allowed gitlab users are checked at the configure stage - substring failure" {


    echo "some.one.else" > "$ALLOWED_GITLAB_USERS_FILE"
    run "$SRC"/configure.sh none noslurm "$ALLOWED_GITLAB_USERS_FILE" 3> /dev/null

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    # some.one configured in the mock of curl
    assert_output --partial "some.one not in allowed gitlab user list."

}

@test "Only if FILENAME passed as 3rd arg to configure, used as allowed gitlab users list." {

    "$SRC"/configure.sh none noslurm 3> /dev/null

}


@test "allowed gitlab users file must have the right permissions and ownership" {

    # shellcheck disable=SC2030,SC2031
    chmod go+w "$ALLOWED_GITLAB_USERS_FILE"
    ls -l "$ALLOWED_GITLAB_USERS_FILE"

    run "$SRC"/configure.sh none noslurm "$ALLOWED_GITLAB_USERS_FILE" 3> /dev/null

    assert_failure
    assert_output --partial "it should not be writable by anybody"
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"

}
