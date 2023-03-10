#!/usr/bin/env bash
# shellcheck disable=SC2317

# This is based on the tutorial for bats
# https://bats-core.readthedocs.io/en/stable/tutorial.html

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

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321

    mkdir "$CUSTOM_ENV_CI_WS/cews_0"
    mkdir "$CUSTOM_ENV_CI_WS/cews_1"
    mkdir "$CUSTOM_ENV_CI_WS/cews_2"


    CEQ_ENV="$CUSTOM_ENV_CI_WS/cews_3/.env"
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
    rm -r "$TEST_PLAYGROUND"

}

@test "sbatch NOT called with --container-* (NOT using pyxis)" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate

    run cat "$MOCKLOGDIR"/sbatch.log
    refute_line --partial '--container'

}


@test "custom executor queue is started in slurm allocation" {


    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate

    wait_until_file_exists "$CEQ_ENV" 10
    # shellcheck disable=SC1090
    source "$CEQ_ENV"

    assert ps -q "$CUSTOM_EXECUTOR_QUEUE_PID"

}

# bats test_tags=onlythis
@test "custom executor queue uses CUSTOM_ENV_CI_WS/cews_N as a workspace" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate

    wait_until_file_exists "$CEQ_ENV" 10
    # shellcheck disable=SC1090
    source "$CEQ_ENV"

    assert_equal "$CUSTOM_ENV_CI_WS/cews_3" "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"


}

@test "the right CUSTOM_ENV_* sbatch variables are visible to sbatch" {


    export CUSTOM_ENV_SBATCH_ACCOUNT='averyimportantone'

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate


    assert_file_contains "$MOCKLOGDIR"/sbatch.log "SBATCH_ACCOUNT=averyimportantone"

}

@test "the WRONG CUSTOM_ENV_* sbatch variables are NOT visible to sbatch" {


    export CUSTOM_ENV_SBATCH_ACCOUNT_WRONG='averyimportantone'

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate


    run cat "$MOCKLOGDIR"/sbatch.log
    refute_output --partial "averyimportantone"

}

@test "the content of 'COMMAND_OPTIONS_SBATCH' is passed to sbatch as part of the parameters" {

    # shellcheck disable=SC2030
    local CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--very-important=long --option"
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate

    assert_file_contains "$MOCKLOGDIR"/sbatch.log "ARGS: $CUSTOM_ENV_COMMAND_OPTIONS_SBATCH"

}

@test "when 'COMMAND_OPTIONS_SBATCH' is not defined, do complain on stderr" {


    # shellcheck disable=SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH=""

    local STDOUT="$TEST_PLAYGROUND/.stdout.test"
    local STDERR="$TEST_PLAYGROUND/.stderr.test"
    "$SRC"/configure-slurm.sh 1> "$STDOUT" \
        2> "$STDERR" \
        3> /dev/null

    assert_file_contains "$STDERR" "Warning: CUSTOM_ENV_COMMAND_OPTIONS_SBATCH not set, working with default options"


    run cat "$STDOUT"
    refute_output --partial "Warning: CUSTOM_ENV_COMMAND_OPTIONS_SBATCH not set, working with default options"


}

@test "script outputs valid json" {

    function _helper() {

    set -o errexit
    local CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--very-important=long --option"
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate

    wait_until_file_exists "$CEQ_ENV" 10
    # shellcheck disable=SC1090
    source "$CEQ_ENV"
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC"/custom_executor_queue.sh
    stop_custom_executor_queue


    }

    run _helper

    assert_success

}

@test "script output has driver.name" {

    function _helper() {

    "$SRC"/configure-slurm.sh 3> /dev/null | python3 -c 'import json,sys;json.load(sys.stdin)["driver"]["name"]'
    }

    run _helper
    assert_success

}


@test "script output has driver.version" {

    function _helper() {

    "$SRC"/configure-slurm.sh 3> /dev/null | python3 -c 'import json,sys;json.load(sys.stdin)["driver"]["version"]'
    }

    run _helper
    assert_success

}

@test "script output has job_env.CE_QUEUE_WORKSPACE (where the .env created by start_custom_executor_queue lives)" {

    function _helper() {

cat <<EOF > scr.py
import json
import sys
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_QUEUE_WORKSPACE"])
EOF
    "$SRC"/configure-slurm.sh 2> /dev/null 3> /dev/null | python3 scr.py
    }

    run _helper
    assert_success

    assert_output "$CUSTOM_ENV_CI_WS/cews_3"
    wait_until_file_exists "$CEQ_ENV" 20
    assert_file_exists "$CEQ_ENV"

}

# bats test_tags=scontrol
@test "configure calls scontrol wait_job" {


    "$SRC"/configure-slurm.sh 2> /dev/null 3> /dev/null

    assert_file_contains "$MOCKLOGDIR"/scontrol.log "wait_job"

}

@test "when job script exits, a file named 'terminated' is produced" {

    "$SRC"/configure-slurm.sh 2> /dev/null 3> /dev/null

    local SBATCHPID
    SBATCHPID=$(awk '{print $1}' "$MOCKLOGDIR"/pids.txt| head -n 1)

    wait_until_file_exists "$CEQ_ENV" 50

    kill -s TERM "$SBATCHPID"
    while ps --pid "$SBATCHPID"
    do
        sleep 1
    done

    assert_exists "$CUSTOM_ENV_CI_WS/cews_3/terminated"

}
