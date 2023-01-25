#!/usr/bin/env bash

function setup() {
    export TRACE=1
    load '../test_helper/bats-support/load'
    load '../test_helper/bats-assert/load'
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    SRC="$PROJECT_ROOT"/src
    export PATH="$SRC:$PATH"
    load_mocks

    TEST_PLAYGROUND="$PWD/prepare-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CE_CONTAINER_NAME="GLCE_54321"
    export CE_IMAGEFILE="$CUSTOM_ENV_CI_WS/image_${CE_CONTAINER_NAME}.sqsh"
    echo "Test setup phase completed."

}

teardown() {

    rm -r "$TEST_PLAYGROUND"
}

@test "enroot called with import" {

    prepare-enroot.sh

    run cat "$MOCKLOGDIR"/enroot.log
    assert_line --regexp "ARGS:.*import.*docker://$CUSTOM_ENV_CI_JOB_IMAGE"

}

@test "images removed at the end" {

    prepare-enroot.sh

    IMAGEFILE=$(grep 'import --output' "$MOCKLOGDIR"/enroot.log | awk '{print $4}')

    assert_not_exists "$IMAGEFILE"


}


@test "enroot called with import and --output to specify an output file for the image based on CE_CONTAINER_NAME" {

    prepare-enroot.sh
    run cat "$MOCKLOGDIR"/enroot.log
    assert_line --regexp "ARGS:.*import.*--output.*image.sqsh"

}

@test "enroot environment variables set correctly" {

    prepare-enroot.sh
    run cat "$MOCKLOGDIR"/enroot.log
    assert_line --partial "ENROOT_RUNTIME_PATH=$CUSTOM_ENV_CI_WS/.enroot/run"
    assert_line --partial "ENROOT_CACHE_PATH=$CUSTOM_ENV_CI_WS/.enroot/cache"
    assert_line --partial "ENROOT_DATA_PATH=$CUSTOM_ENV_CI_WS/.enroot/data"

}


@test "enroot removed called only if container already exists" {

    prepare-enroot.sh
    run cat "$MOCKLOGDIR"/enroot.log

    refute_line --partial "remove $CE_CONTAINER_NAME"

}

@test "enroot called to remove container with same name as the one to be created" {

    enroot create --name "$CE_CONTAINER_NAME" imagename-ignored.sqsh
    prepare-enroot.sh
    run cat "$MOCKLOGDIR"/enroot.log

    assert_line --partial "remove $CE_CONTAINER_NAME"

}


# bats test_tags=notworking
@test "enroot remove called with yes"  {

    enroot create --name "$CE_CONTAINER_NAME" imagename-ignored.sqsh
    prepare-enroot.sh


    LOG="$MOCKLOGDIR"/enroot.log
    CUTLOG="$MOCKLOGDIR"/.enroot-cut-log
    # Notice the spaces surrounding 'remove'
    # to make sure it does not pick lines where the directory name
    # is used.
    START=$(grep -nE 'ARGS:.* remove ' "$LOG" | cut -d: -f1)

    set -o pipefail
    tail -n +$((START+1)) "$LOG" > "$CUTLOG"
    END=$({ grep -n "ARGS:" "$CUTLOG" | cut -d: -f1; } || { E=$(wc -l < "$CUTLOG"); echo $((E+1)); })
    set +o pipefail

    function _helper(){
        # shellcheck disable=SC2317
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

@test "enroot should not be called at all if \$CUSTOM_ENV_CI_JOB_IMAGE is not defined" {

    (
    export CUSTOM_ENV_CI_JOB_IMAGE=""
    prepare-enroot.sh
    )
    assert_not_exists "$MOCKLOGDIR"/enroot.log

}
