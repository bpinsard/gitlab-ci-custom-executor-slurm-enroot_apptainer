#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'
    load '../test_helper/bats-file/load'
    load '../test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    load_mocks
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/configure-envsave-test-$BATS_TEST_NAME"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=docker://alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_DEFAULT_PARTITION=default-partition

    CEQ_ENV="$CUSTOM_ENV_CI_WS/cews_0"/.env
    echo "Test setup phase completed."
}

function teardown() {
    wait_until_file_exists "$CEQ_ENV" 50
    # shellcheck disable=SC1090
    source "$CEQ_ENV"
    # shellcheck disable=SC1091
    source "$SRC"/custom_executor_queue.sh
    stop_custom_executor_queue
    awk '{print $1}' "$MOCKLOGDIR"/pids.txt | xargs kill
    try_to_remove_dir "$TEST_PLAYGROUND"

}


@test "configure saves all slurm variables in WORKSPACE/slurmenv" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate

    assert_exists "$CUSTOM_ENV_CI_WS/cews_0/slurmenv"

}

@test "WORKSPACE/slurmenv contains SBATCH input variables and COMMAND_OPTIONS_SBATCH" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    SLURMENV="$CUSTOM_ENV_CI_WS/cews_0/slurmenv"
    for VAR in $("$SRC"/slurm-utils/get-sbatch-input-env-list.sh)
    do
        run grep "$VAR" "$SLURMENV"
        assert_success
    done
    run grep COMMAND_OPTIONS_SBATCH "$SLURMENV"
    assert_success

}

@test "WORKSPACE/slurmenv contains values of SBATCH input variables and COMMAND_OPTIONS_SBATCH" {

    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--ntasks=5 --gres=gpu:2"
    export CUSTOM_ENV_SBATCH_REQUEUE="something-like-this"


    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    SLURMENV="$CUSTOM_ENV_CI_WS/cews_0/slurmenv"
    cat "$SLURMENV"
    assert_file_contains "$SLURMENV" "COMMAND_OPTIONS_SBATCH=--ntasks=5 --gres=gpu:2"
    assert_file_contains "$SLURMENV" "SBATCH_REQUEUE=something-like-this"

}
