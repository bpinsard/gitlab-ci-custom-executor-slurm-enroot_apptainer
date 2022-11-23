#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PATH"
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND=$PWD/$(mktemp -d configure-testXXXXXXX)
    echo "Created test playground at $TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest
    echo "Test setup phase completed."
    
    (
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC"/custom_executor_queue.sh
    start_custom_executor_queue "$CUSTOM_ENV_CI_BUILDS_DIR" 
    )
}

function wait_until_file_exists() {
    local FILE="$1"
    local MAXDELAY="$2"
    local T0="$SECONDS"
    while [[ ! -f "$FILE" && "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done

}

function teardown() {
    wait_until_file_exists "$CUSTOM_ENV_CI_BUILDS_DIR"/.env 30
    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env
    # shellcheck disable=SC1091
    source "$SRC"/custom_executor_queue.sh
    stop_custom_executor_queue
    rm -r "$TEST_PLAYGROUND"

}

ALL_STEP_NAMES=(prepare_script
                get_sources
                restore_cache
                download_artifacts
                step_before
                build_script
                step_after
                after_script
                archive_cache
                archive_cache_on_failure
                upload_artifacts_on_success
                upload_artifacts_on_failure
                cleanup_file_variables)

STEPS_IN_CONTAINER=(prepare_script
                    step_before
                    build_script
                    step_after
                    after_script
                    cleanup_file_variables)

STEPS_OUT_CONTAINER=(get_sources
                     restore_cache
                     download_artifacts
                     archive_cache
                     archive_cache_on_failure
                     upload_artifacts_on_success
                     upload_artifacts_on_failure)

@test "step name lists are consistent" {

    for STEPNAME in "${ALL_STEP_NAMES[@]}"
    do
        echo "Checking $STEPNAME"
        local FOUND_IN=0
        local FOUND_OUT=0
        echo "is in 'IN_CONTAINER' list?"
        for S in "${STEPS_IN_CONTAINER[@]}"
        do
            if [ "$STEPNAME" == "$S" ]
            then
                FOUND_IN=1
            fi
        done
        echo "is in 'OUT_CONTAINER' list?"
        for S in "${STEPS_OUT_CONTAINER[@]}"
        do
            if [ "$STEPNAME" == "$S" ]
            then
                if [ "$FOUND_IN" -ne 0 ]
                then
                echo "$STEPNAME found twice!"
                assert false
                fi
                FOUND_OUT=1
            fi
        done
        if  [ "$FOUND_IN" -ne 1 ] && [ "$FOUND_OUT" -ne 1 ]
        then
            echo "$STEPNAME not found!"
            assert false
        fi
    done
}


@test "run script should run its first argument" {


    for STEP in "${ALL_STEP_NAMES[@]}"
    do
cat << EOF > script-"$STEP".sh

touch script-output-"$STEP".txt

EOF
    chmod +x ./script-"$STEP".sh

    "$SRC"/run.sh ./script-"$STEP".sh "$STEP"

    assert [ -f script-output-"$STEP".txt ]
    done

}

@test "step that needs to happen in the container run in the custom executor queue" {

    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env

    for STEP in "${STEPS_IN_CONTAINER[@]}"
    do
       cat << EOF > script-"$STEP".sh

sleep 3
touch script-output-"$STEP".txt

EOF
       chmod +x ./script-"$STEP".sh

       "$SRC"/run.sh ./script-"$STEP".sh "$STEP"

       # shellcheck disable=SC2031
       run cat "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"
       assert_output --partial "script-$STEP.sh"

    done

}

@test "run blocks until the script is executed" {

    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env

    for STEP in "${STEPS_IN_CONTAINER[@]}"
    do
       cat << EOF > script-"$STEP".sh

sleep 3
touch script-output-"$STEP".txt

EOF
       chmod +x ./script-"$STEP".sh

       "$SRC"/run.sh ./script-"$STEP".sh "$STEP"
       assert [ -f script-output-"$STEP".txt ]

    done

}


@test "if two submitted scripts have the same name, run will wait till the end of the second" {
    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env

       cat << EOF > script.sh
sleep 3
touch script-output.txt
EOF
       chmod +x ./script.sh

       "$SRC"/run.sh ./script.sh prepare_script
       cat << EOF > script.sh
sleep 3
touch script-output-second-time.txt
EOF
       chmod +x ./script.sh
       "$SRC"/run.sh ./script.sh prepare_script

       assert [ -f script-output-second-time.txt ]

}

@test "run outputs what the script outputs." {
    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env
    for STEP in "${ALL_STEP_NAMES[@]}"
    do
cat << EOF > script-"$STEP".sh

echo "Hello from $STEP"

EOF
    chmod +x ./script-"$STEP".sh

    run "$SRC"/run.sh ./script-"$STEP".sh "$STEP"

    assert_output "Hello from $STEP"
    done



}
