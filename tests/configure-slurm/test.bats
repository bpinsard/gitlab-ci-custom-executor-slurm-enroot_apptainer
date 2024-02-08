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

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci-ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42

    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_DEFAULT_PARTITION=default-partition

    mkdir "$CUSTOM_ENV_CI_WS/cews_0"
    mkdir "$CUSTOM_ENV_CI_WS/cews_1"
    touch "$CUSTOM_ENV_CI_WS/cews_1/.env"
    mkdir "$CUSTOM_ENV_CI_WS/cews_2"
    touch "$CUSTOM_ENV_CI_WS/cews_2/.env"
    touch "$CUSTOM_ENV_CI_WS/cews_2/slurmenv"


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
    while [ -d "$TEST_PLAYGROUND" ]
    do
        try_to_remove_dir "$TEST_PLAYGROUND" || echo "Failed removal, retrying in one sec..."
        sleep 1
    done

}

@test "sbatch NOT called with --container-* (NOT using pyxis)" {

    "$SRC"/configure.sh none useslurm 3> /dev/null | json_validate

    run cat "$MOCKLOGDIR"/sbatch.log
    refute_line --partial '--container'

}

@test "Relevant diagnostics is given when testing workspaces and CE_DEBUG_LVL>0" {

    export CUSTOM_ENV_CE_DEBUG_LVL=1
    run "$SRC"/configure.sh none useslurm 3> /dev/null
    assert_output --regexp "cews_0 has no env"
    assert_output --regexp "cews_1 has no slurmenv"
    assert_output --regexp "slurmenv is different for .*cews_2"

}


@test "custom executor queue is started in (mocked) slurm allocation" {


    "$SRC"/configure.sh none useslurm 3> /dev/null | json_validate

    wait_until_file_exists "$CEQ_ENV" 10
    # shellcheck disable=SC1090
    source "$CEQ_ENV"

    assert ps -q "$CUSTOM_EXECUTOR_QUEUE_PID"

}

@test "custom executor queue uses CUSTOM_ENV_CI_WS/cews_N as a workspace" {

    "$SRC"/configure.sh none useslurm 3> /dev/null | json_validate

    wait_until_file_exists "$CEQ_ENV" 10
    # shellcheck disable=SC1090
    source "$CEQ_ENV"

    assert_equal "$CUSTOM_ENV_CI_WS/cews_3" "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"


}

@test "the right CUSTOM_ENV_* sbatch variables are visible to sbatch" {


    export CUSTOM_ENV_SBATCH_ACCOUNT='averyimportantone'

    "$SRC"/configure.sh none useslurm 3> /dev/null | json_validate


    assert_file_contains "$MOCKLOGDIR"/sbatch.log "SBATCH_ACCOUNT=averyimportantone"

}

@test "the WRONG CUSTOM_ENV_* sbatch variables are NOT visible to sbatch" {


    export CUSTOM_ENV_SBATCH_ACCOUNT_WRONG='averyimportantone'

    "$SRC"/configure.sh none useslurm 3> /dev/null | json_validate


    run cat "$MOCKLOGDIR"/sbatch.log
    refute_output --partial "averyimportantone"

}

@test "the content of 'COMMAND_OPTIONS_SBATCH' is passed to sbatch as part of the parameters" {

    # shellcheck disable=SC2030
    local CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--very-important=long --option"
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH

    "$SRC"/configure.sh none useslurm 3> /dev/null | json_validate

    assert_file_contains "$MOCKLOGDIR"/sbatch.log "ARGS: $CUSTOM_ENV_COMMAND_OPTIONS_SBATCH"

}

@test "when 'COMMAND_OPTIONS_SBATCH' is not defined, do complain on stderr" {


    # shellcheck disable=SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH=""

    local STDOUT="$TEST_PLAYGROUND/.stdout.test"
    local STDERR="$TEST_PLAYGROUND/.stderr.test"
    "$SRC"/configure.sh none useslurm 1> "$STDOUT" \
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

    "$SRC"/configure.sh none useslurm 3> /dev/null | json_validate

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

    "$SRC"/configure.sh none useslurm 3> /dev/null | python3 -c 'import json,sys;json.load(sys.stdin)["driver"]["name"]'
    }

    run _helper
    assert_success

}

@test "script output has builds_dir and it is in CI_WS,contains CI_CONCURRENT_ID and backend" {

    function _helper() {

    "$SRC"/configure.sh a-backend useslurm 3> /dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["builds_dir"])'
    }

    run _helper
    assert_success
    assert_output --regexp "$CUSTOM_ENV_CI_WS"
    assert_output --regexp "a-backend"
    assert_output --regexp "$CUSTOM_ENV_CI_CONCURRENT_ID"

}

@test "script output has driver.version" {

    function _helper() {

    "$SRC"/configure.sh none useslurm 3> /dev/null | python3 -c 'import json,sys;json.load(sys.stdin)["driver"]["version"]'
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
    "$SRC"/configure.sh none useslurm 2> /dev/null 3> /dev/null | python3 scr.py
    }

    run _helper
    assert_success

    assert_output "$CUSTOM_ENV_CI_WS/cews_3"
    wait_until_file_exists "$CEQ_ENV" 20
    assert_file_exists "$CEQ_ENV"

}

# bats test_tags=scontrol
@test "configure calls scontrol wait_job" {


    "$SRC"/configure.sh none useslurm 2> /dev/null 3> /dev/null

    assert_file_contains "$MOCKLOGDIR"/scontrol.log "wait_job"

}

@test "when job script exits, a file named 'terminated' is produced" {

    "$SRC"/configure.sh none useslurm 2> /dev/null 3> /dev/null

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
@test "when envs match and time is enough, the allocation is reused" {

    # shellcheck disable=SC2030
    export SLURM_JOB_ID=34343434 # the squeue mock gives us 10 min more
    "$SRC"/configure.sh none useslurm 3> /dev/null | read-job-env.py > env1

    # shellcheck disable=SC2030
    export CUSTOM_ENV_JOB_TIME_SEC=500
    "$SRC"/configure.sh none useslurm 3> /dev/null | read-job-env.py > env2

    assert_equal "$(diff env1 env2 | wc -l )" 0
    assert_file_contains env1 "cews_3"
}
@test "when envs match but time does not, the allocation is not reused" {

    # shellcheck disable=SC2031
    export SLURM_JOB_ID=34343434 # the squeue mock gives us 10 min more
    "$SRC"/configure.sh none useslurm 3> /dev/null | read-job-env.py > env1

    # shellcheck disable=SC2031
    export CUSTOM_ENV_JOB_TIME_SEC=1200
    "$SRC"/configure.sh none useslurm 3> /dev/null | read-job-env.py > env2

    assert_file_contains env1 "cews_3"
    assert_file_contains env2 "cews_4"

}
@test "custom executor max idle time sec can be set via env var" {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC=4
    "$SRC"/configure.sh none useslurm 3> /dev/null | read-job-env.py > env1

    # shellcheck disable=SC1091
    source ./env1
    assert_file_contains "$CE_QUEUE_WORKSPACE/.env" 'CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC="4"'

}
@test "when there is too little idle time left, the allocation is not reused" {

    # shellcheck disable=SC2031
    export CUSTOM_EXECUTOR_QUEUE_MAX_IDLE_TIME_SEC=20
    "$SRC"/configure.sh none useslurm 3> /dev/null | read-job-env.py > env1

    sleep 10

    "$SRC"/configure.sh none useslurm 3> /dev/null | read-job-env.py > env2

    assert_file_contains env1 "cews_3"
    assert_file_contains env2 "cews_4"

}

@test "configure-slurm creates job.slurm from template in a workspace and submits it with sbatch" {

    "$SRC"/configure.sh none useslurm 3> /dev/null

    NEWJOBSLURM="$CUSTOM_ENV_CI_WS/cews_3/job.slurm"
    assert_exist "$NEWJOBSLURM"
    assert_file_contains "$MOCKLOGDIR"/sbatch.log "$NEWJOBSLURM"

}

@test "configure-slurm creates the builds_dir directory" {


    "$SRC"/configure.sh none useslurm 3> /dev/null | read-job-env.py > env1
    (
        # shellcheck disable=SC1091
        . env1
        assert_dir_exists "$CUSTOM_ENV_CI_BUILDS_DIR"
    )

}
