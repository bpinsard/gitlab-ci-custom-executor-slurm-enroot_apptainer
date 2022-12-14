#!/usr/bin/env bash
# shellcheck disable=SC2317

# This is based on the tutorial for bats
# https://bats-core.readthedocs.io/en/stable/tutorial.html

function setup() {
    export TRACE=1
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PATH"
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND=$PWD/$(mktemp -d configure-testXXXXXXX)
    export MOCKLOGDIR=$TEST_PLAYGROUND
    echo "Created test playground at $TEST_PLAYGROUND" >&3

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    CEQ_ENV="$CUSTOM_ENV_CI_BUILDS_DIR"/cews/.env
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

    assert ps -q "$CUSTOM_EXECUTOR_QUEUE_JOBID"

}

@test "custom executor queue uses \$CUSTOM_ENV_CI_BUILDS_DIR/cews as a workspace" {

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate

    wait_until_file_exists "$CEQ_ENV" 10
    # shellcheck disable=SC1090
    source "$CEQ_ENV"

    assert_equal "$CUSTOM_ENV_CI_BUILDS_DIR"/cews "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"


}

@test "the right CUSTOM_ENV_* sbatch variables are visible to sbatch" {


    export CUSTOM_ENV_SBATCH_ACCOUNT='averyimportantone'

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate


    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "SBATCH_ACCOUNT=averyimportantone"

}

@test "the WRONG CUSTOM_ENV_* sbatch variables are NOT visible to sbatch" {


    export CUSTOM_ENV_SBATCH_ACCOUNT_WRONG='averyimportantone'

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate


    run cat "$MOCKLOGDIR"/sbatch.log
    refute_output --partial "averyimportantone"

}

@test "the content of 'COMMAND_OPTIONS_SBATCH' is passed to sbatch as part of the parameters" {

    local CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--very-important=long --option"
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH

    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate

    run cat "$MOCKLOGDIR"/sbatch.log

    assert_output --partial "ARGS: $CUSTOM_ENV_COMMAND_OPTIONS_SBATCH"

}

@test "when 'COMMAND_OPTIONS_SBATCH' is not defined, do complain on stderr" {


    local STDOUT="$TEST_PLAYGROUND/.stdout.test"
    local STDERR="$TEST_PLAYGROUND/.stderr.test"
    "$SRC"/configure-slurm.sh 1> "$STDOUT" \
        2> "$STDERR" \
        3> /dev/null

    run cat "$STDERR"
    assert_output --partial "Warning: CUSTOM_ENV_COMMAND_OPTIONS_SBATCH not set, working with default options"


    run cat "$STDOUT"
    refute_output --partial "Warning: CUSTOM_ENV_COMMAND_OPTIONS_SBATCH not set, working with default options"


}

@test "when 'COMMAND_OPTIONS_SBATCH' is not defined, use --partition=dev_cpuonly -n 1 -t 30" {


    "$SRC"/configure-slurm.sh 3> /dev/null | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
   assert_output --regexp '--partition=dev_cpuonly\s+-n\s+1\s+-t\s+30'

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

@test "script output has job_env.CE_SLURM_JOB_ID which contains the JOB ID of the allocation" {

    function _helper() {

cat <<EOF > scr.py
import json
import sys
dump = json.load(sys.stdin)
int(dump["job_env"]["CE_SLURM_JOB_ID"])
EOF
    "$SRC"/configure-slurm.sh 3> /dev/null | python3 scr.py
    }

    run _helper
    assert_success

}

@test "script output has job_env.CE_QUEUE_ENV_PATH (where the .env created by start_custom_executor_queue lives)" {

    function _helper() {

cat <<EOF > scr.py
import json
import sys
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_QUEUE_ENV_PATH"])
EOF
    "$SRC"/configure-slurm.sh 2> /dev/null 3> /dev/null | python3 scr.py
    }

    run _helper
    assert_success

    assert_output "$CEQ_ENV"
    wait_until_file_exists "$CEQ_ENV" 20
    assert [ -f "$CEQ_ENV" ]

}

@test "script output has job_env.CE_CONTAINER_NAME which contains CUSTOM_ENV_CI_JOB_ID" {



    function _helper() {

cat <<EOF > scr.py
import json
import sys
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_CONTAINER_NAME"])
EOF
    "$SRC"/configure-slurm.sh 2> /dev/null 3> /dev/null | python3 scr.py
    }

    run _helper
    assert_success

    assert_output --partial "GLCE_$CUSTOM_ENV_CI_JOB_ID"

}
