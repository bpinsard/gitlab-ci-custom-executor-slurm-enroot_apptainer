#!/usr/bin/env bash


function setup() {
    export TRACE=1
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    SRC="$PROJECT_ROOT"/src
    export PATH="$PROJECT_ROOT/tests/mocks/bin:$SRC:$PATH"

    TEST_PLAYGROUND=$PWD/$(mktemp -d prepare-testXXXXXXX)
    export MOCKLOGDIR=$TEST_PLAYGROUND
    echo "Created test playground at $TEST_PLAYGROUND" >&3

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CE_CONTAINER_NAME=TestContainer
    echo "Test setup phase completed."

}

teardown() {

    rm -r "$TEST_PLAYGROUND"
}

@test "enroot called with import " {

    prepare-enroot.sh

    run cat "$MOCKLOGDIR"/enroot.log
    assert_line --regexp "ARGS:.*import docker://$CUSTOM_ENV_CI_JOB_IMAGE"

}

@test "enroot environment variables set correctly" {

    prepare-enroot.sh
    run cat "$MOCKLOGDIR"/enroot.log
    assert_line --partial "ENROOT_RUNTIME_PATH=$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/run"
    assert_line --partial "ENROOT_CACHE_PATH=$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/cache"
    assert_line --partial "ENROOT_DATA_PATH=$CUSTOM_ENV_CI_BUILDS_DIR/.enroot/data"

}

@test "enroot removed called only if container already exists" {

    prepare-enroot.sh
    run cat "$MOCKLOGDIR"/enroot.log

    refute_line --partial "remove $CE_CONTAINER_NAME"

}

@test "enroot called to remove container with same name as the one to be created" {

    enroot create --name "$CE_CONTAINER_NAME"
    prepare-enroot.sh
    run cat "$MOCKLOGDIR"/enroot.log

    assert_line --partial remove "$CE_CONTAINER_NAME"

}

@test "enroot remove called with yes"  {

    enroot create --name "$CE_CONTAINER_NAME"
    prepare-enroot.sh

    LOG="$MOCKLOGDIR"/enroot.log
    START=$(grep -nE 'ARGS:.*remove' "$LOG" | cut -d: -f1)

    set -o pipefail
    CUTLOG=$MOCKLOGDIR/.enroot-cut-log
    tail -n +$((START+1)) "$LOG" > "$CUTLOG"
    END=$({ grep -n "ARGS:" "$CUTLOG" | cut -d: -f1; } || { E=$(wc -l < "$CUTLOG"); echo $((E+1)); })
    set +o pipefail

    function _helper(){

        head -n $((END+START)) "$LOG" | tail -n $((START+1))
    }

    run _helper
    assert_output --regexp "yes"

}

@test "enroot creates container with the right name" {

    prepare-enroot.sh
    run enroot list

    assert_output "$CE_CONTAINER_NAME"

}
