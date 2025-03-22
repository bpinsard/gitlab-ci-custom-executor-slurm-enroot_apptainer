#!/usr/bin/env bash
# shellcheck disable=SC2317

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

    TEST_PLAYGROUND="$PWD/configure-noslurm-test-$BATS_TEST_NAME"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci-ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42

    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321

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

@test "script outputs valid json (no slurm)" {

    function _helper() {

    set -o errexit
    local CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--very-important=long --option"
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH

    "$SRC"/configure.sh none noslurm 3> /dev/null | json_validate

    }

    run _helper

    assert_success

}

@test "script output has driver.name (no slurm)" {

    function _helper() {

    "$SRC"/configure.sh none noslurm 3> /dev/null | python3 -c 'import json,sys;json.load(sys.stdin)["driver"]["name"]'
    }

    run _helper
    assert_success

}

@test "script output has builds_dir and it is in CI_WS,contains CI_CONCURRENT_ID and backend (no slurm)" {

    function _helper() {

    "$SRC"/configure.sh a-backend noslurm 3> /dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["builds_dir"])'
    }

    run _helper
    assert_success
    assert_output --regexp "$CUSTOM_ENV_CI_WS"
    assert_output --regexp "a-backend"
    assert_output --regexp "$CUSTOM_ENV_CI_CONCURRENT_ID"

}

@test "script output has driver.version (no slurm)" {

    function _helper() {

    "$SRC"/configure.sh none noslurm 3> /dev/null | python3 -c 'import json,sys;json.load(sys.stdin)["driver"]["version"]'
    }

    run _helper
    assert_success

}

@test "configure-slurm creates the builds_dir directory (no slurm)" {


    "$SRC"/configure.sh none noslurm 3> /dev/null | read-job-env.py > env1
    (
        # shellcheck disable=SC1091
        . env1
        assert_dir_exists "$CUSTOM_ENV_CI_BUILDS_DIR"
    )

}

@test "Not much diagnostics is given when testing workspaces if CE_DEBUG_LVL=0 (noslurm)" {

    export CUSTOM_ENV_CE_DEBUG_LVL=0
    run "$SRC"/configure.sh none noslurm 3> /dev/null
    refute_output --regexp "cews_0 has no env"
    refute_output --regexp "cews_1 has no slurmenv"
    refute_output --regexp "slurmenv is different for .*cews_2"
    refute_output --partial "#SBATCH"


    # the json is contained only once in the output, i.e. not in stderr
    [ "$(echo "$output" | grep -c builds_dir)" -eq 1 ]

}
