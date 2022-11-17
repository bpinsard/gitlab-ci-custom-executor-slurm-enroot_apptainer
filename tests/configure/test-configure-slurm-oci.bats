#!/usr/bin/env bash

# This is based on the tutorial for bats
# https://bats-core.readthedocs.io/en/stable/tutorial.html

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PATH"
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND=$PWD/$(mktemp -d configure-testXXXXXXX)
    export MOCKLOGDIR=$TEST_PLAYGROUND
    echo "Created test playground at $TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    echo "Test setup phase completed."
}

function json_validate () {
    python3 -c 'import json,sys;json.load(sys.stdin)' || ( echo "JSON validation failed" && exit 1 )
}

function teardown() {
    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env
    # shellcheck disable=SC1091
    source "$SRC"/allocation_manager.sh
    stop_allocation_manager
    rm -r "$TEST_PLAYGROUND"

}
@test "/scratch in container mounts" {

    "$SRC"/configure-slurm-oci.sh | json_validate

    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial '/scratch:/scratch'

}


@test "prolog script in container mounts" {

    "$SRC"/configure-slurm-oci.sh | json_validate

    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial '/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk'

}

@test "\$CUSTOM_ENV_CI_BUILDS_DIR in container mounts" {

    "$SRC"/configure-slurm-oci.sh | json_validate

    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "$CUSTOM_ENV_CI_BUILDS_DIR:$CUSTOM_ENV_CI_BUILDS_DIR"

}

@test "allocation manager is started in slurm allocation" {


    "$SRC"/configure-slurm-oci.sh | json_validate

    assert [ -f "$TEST_PLAYGROUND"/.env ]
    # shellcheck disable=SC1091
    source "$TEST_PLAYGROUND"/.env

    assert ps -q "$ALLOCATION_MANAGER_JOBID"

}

@test "allocation manager uses \$CUSTOM_ENV_CI_BUILDS_DIR as a workspace" {

    "$SRC"/configure-slurm-oci.sh | json_validate
    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env

    assert_equal "$CUSTOM_ENV_CI_BUILDS_DIR" "$ALLOCATION_MANAGER_WORKSPACE"


}

@test "the right CUSTOM_ENV_* sbatch variables are visible to sbatch" {


    export CUSTOM_ENV_SBATCH_ACCOUNT='averyimportantone'

    "$SRC"/configure-slurm-oci.sh | json_validate


    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "SBATCH_ACCOUNT=averyimportantone"

}

@test "the WRONG CUSTOM_ENV_* sbatch variables are NOT visible to sbatch" {


    export CUSTOM_ENV_SBATCH_ACCOUNT_WRONG='averyimportantone'

    "$SRC"/configure-slurm-oci.sh | json_validate


    run cat "$MOCKLOGDIR"/sbatch.log
    refute_output --partial "averyimportantone"

}

@test "the content of 'COMMAND_OPTIONS_SBATCH' is passed to sbatch as part of the parameters" {

    local CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--very-important long --option"
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH

    "$SRC"/configure-slurm-oci.sh | json_validate

    run cat "$MOCKLOGDIR"/sbatch.log

    assert_output --partial "ARGS: $CUSTOM_ENV_COMMAND_OPTIONS_SBATCH"

}

@test "when 'COMMAND_OPTIONS_SBATCH' is not defined, do complain on stderr" {


    local STDOUT="$TEST_PLAYGROUND/.stdout.test"
    local STDERR="$TEST_PLAYGROUND/.stderr.test"
    "$SRC"/configure-slurm-oci.sh 1> "$STDOUT" \
                                  2> "$STDERR"

    run cat "$STDERR"
    assert_output --partial "Warning: CUSTOM_ENV_COMMAND_OPTIONS_SBATCH not set, working with default options"


    run cat "$STDOUT"
    refute_output --partial "Warning: CUSTOM_ENV_COMMAND_OPTIONS_SBATCH not set, working with default options"


}

@test "when 'COMMAND_OPTIONS_SBATCH' is not defined, use --partition=cpu_only -n 1 -t 30" {


    "$SRC"/configure-slurm-oci.sh | json_validate
    run cat "$MOCKLOGDIR"/sbatch.log
   assert_output --regexp "--partition=cpu_only\s+-n\s+1\s+-t\s+30"

}

@test "script outputs valid json" {

    function _helper() {
    set -o errexit
    local CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--very-important long --option"
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH

    "$SRC"/configure-slurm-oci.sh | json_validate


    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env
    # shellcheck disable=SC1091
    source "$SRC"/allocation_manager.sh
    stop_allocation_manager


    }

    run _helper

    assert_success

}

@test "script output has driver.name" {

    function _helper() {

    "$SRC"/configure-slurm-oci.sh | python3 -c 'import json,sys;json.load(sys.stdin)["driver"]["name"]'
    }

    run _helper
    assert_success

}


@test "script output has driver.version" {

    function _helper() {

    "$SRC"/configure-slurm-oci.sh | python3 -c 'import json,sys;json.load(sys.stdin)["driver"]["version"]'
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
    "$SRC"/configure-slurm-oci.sh | python3 scr.py
    }

    run _helper
    assert_success

}

@test "script output has job_env.CE_ALLOCATION_MANAGER_ENV_PATH (where the .env created by start_allocation_manager lives)" {

    function _helper() {

cat <<EOF > scr.py
import json
import sys
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_ALLOCATION_MANAGER_ENV_PATH"])
EOF
    "$SRC"/configure-slurm-oci.sh 2> /dev/null | python3 scr.py
    }

    run _helper
    assert_success

    assert_output "$CUSTOM_ENV_CI_BUILDS_DIR"/.env
    assert [ -f  "$CUSTOM_ENV_CI_BUILDS_DIR"/.env ]

}
