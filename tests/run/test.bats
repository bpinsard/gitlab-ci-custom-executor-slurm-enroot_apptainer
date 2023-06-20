#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load'
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    load_mocks

    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/run-test-$BATS_TEST_NAME"
    mkdir "$TEST_PLAYGROUND"
    # outside CUSTOM_ENV_CI_WS
    TMP_PLAYGROUND=$(mktemp -d /tmp/run-testXXXXXXX)
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND/builds"
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_CI_JOB_IMAGE=docker://alpine:latest
    echo "Test setup phase completed."
    
    (
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC"/custom_executor_queue.sh
    start_custom_executor_queue "$CUSTOM_ENV_CI_WS/cews_0" 3> /dev/null
    )
    export CE_QUEUE_WORKSPACE="$CUSTOM_ENV_CI_WS/cews_0"
}

function teardown() {
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 30

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"
    # shellcheck disable=SC1091
    source "$SRC"/custom_executor_queue.sh
    stop_custom_executor_queue
    try_to_remove_dir "$TEST_PLAYGROUND"
    rm -r "$TMP_PLAYGROUND"

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


@test "run script should run its second argument" {


    for STEP in "${STEPS_IN_CONTAINER[0]}" "${STEPS_OUT_CONTAINER[0]}"
    do
    echo "# testing $STEP..."
cat << EOF > script-"$STEP".sh

touch script-output-"$STEP".txt

EOF
    chmod +x ./script-"$STEP".sh

    "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"

    assert_exists script-output-"$STEP".txt
    done

}

@test "all steps run in the custom executor queue" {

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    for STEP in "${STEPS_IN_CONTAINER[0]}" "${STEPS_OUT_CONTAINER[0]}"
    do
       cat << EOF > script-"$STEP".sh

sleep 3
touch script-output-"$STEP".txt

EOF
       chmod +x ./script-"$STEP".sh

       "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"

       # shellcheck disable=SC2031
       assert_file_contains "$CUSTOM_EXECUTOR_QUEUE_LOGFILE" "script-$STEP.sh"

    done

}

@test "run blocks until the script is executed" {

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

    STEP="${STEPS_IN_CONTAINER[0]}"
    cat << EOF > script-"$STEP".sh
sleep 3
touch script-output-"$STEP".txt
EOF
    chmod +x ./script-"$STEP".sh

    "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"
    assert_exists script-output-"$STEP".txt

}


@test "if two submitted scripts have the same name, run will wait till the end of the second" {
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"

       cat << EOF > script.sh
sleep 3
touch script-output.txt
EOF
       chmod +x ./script.sh

       "$SRC"/run.sh enroot ./script.sh prepare_script
       cat << EOF > script.sh
sleep 3
touch script-output-second-time.txt
EOF
       chmod +x ./script.sh
       "$SRC"/run.sh enroot ./script.sh prepare_script

       assert_exists script-output-second-time.txt

}

@test "run outputs what the script outputs." {
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"
    for STEP in "${STEPS_IN_CONTAINER[0]}" "${STEPS_OUT_CONTAINER[0]}"
    do
cat << EOF > script-"$STEP".sh

echo "Hello from $STEP"

EOF
    chmod +x ./script-"$STEP".sh

    run "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"

    assert_line "Hello from $STEP"
    done

}

@test "run exits with the same code as the script." {
    # shellcheck disable=SC2030
    export SYSTEM_FAILURE_EXIT_CODE=102
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"
    for STEP in "${STEPS_IN_CONTAINER[0]}" "${STEPS_OUT_CONTAINER[0]}"
    do
cat << EOF > script-"$STEP".sh

exit 42

EOF
    chmod +x ./script-"$STEP".sh

    echo "Testing $STEP"
    run "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"
    assert_equal "$status" 42
    done

}

@test "run exits with \$SYSTEM_FAILURE_EXIT_CODE if an erroneus step name is given" {

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"
    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

cat << EOF > script.sh

echo "won't run"

EOF
    chmod +x ./script.sh

    run "$SRC/run.sh" enroot ./script.sh

    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"

}

@test "run exits with \$SYSTEM_FAILURE_EXIT_CODE if CE_QUEUE_WORKSPACE is not defined" {

    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

    (

    # shellcheck disable=SC2030
    export CE_QUEUE_WORKSPACE=""

cat << EOF > script.sh

echo "won't run"

EOF
    chmod +x ./script.sh

    run "$SRC/run.sh" enroot ./script.sh get_sources

    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    )


}

@test "run uses enroot for the steps \"in container\" if enroot is specified as first arg" {

   STEPNAME="${STEPS_IN_CONTAINER[0]}"
   ENROOTLOG="$MOCKLOGDIR"/enroot.log
   # cleanup
   rm -f "$ENROOTLOG"
   cat << EOF > script-"$STEPNAME".sh

touch "$TEST_PLAYGROUND"/script-output-"$STEPNAME".txt

EOF
   chmod +x ./script-"$STEPNAME".sh

   "$SRC/run.sh" enroot ./script-"$STEPNAME".sh "$STEPNAME" 3>/dev/null

   assert_exists "$TEST_PLAYGROUND/script-output-$STEPNAME".txt
   assert_exists "$ENROOTLOG"

}

@test "run uses apptainer for the steps \"in container\" if apptainer is specified as first arg" {

   STEPNAME="${STEPS_IN_CONTAINER[0]}"
   APPTAINERLOG="$MOCKLOGDIR"/apptainer.log
   # cleanup
   rm -f "$APPTAINERLOG"
   cat << EOF > script-"$STEPNAME".sh

touch "$TEST_PLAYGROUND"/script-output-"$STEPNAME".txt

EOF
   chmod +x ./script-"$STEPNAME".sh

   "$SRC/run.sh" apptainer ./script-"$STEPNAME".sh "$STEPNAME" 3>/dev/null

   assert_exists "$TEST_PLAYGROUND/script-output-$STEPNAME".txt
   assert_exists "$APPTAINERLOG"

}



@test "run does not run anything in a container if CUSTOM_ENV_CI_JOB_IMAGE not defined" {

   (
   # shellcheck disable=SC2030
   export CUSTOM_ENV_CI_JOB_IMAGE=""

   STEPNAME="${STEPS_IN_CONTAINER[0]}"

   ENROOTLOG="$MOCKLOGDIR"/enroot.log
   # cleanup
   rm -f "$ENROOTLOG"
   cat << EOF > script-"$STEPNAME".sh
touch "$TEST_PLAYGROUND"/script-output-"$STEPNAME".txt
EOF
   chmod +x ./script-"$STEPNAME".sh
   "$SRC/run.sh" enroot ./script-"$STEPNAME".sh "$STEPNAME" 3>/dev/null
   assert_exists "$TEST_PLAYGROUND/script-output-$STEPNAME".txt
   assert_not_exists "$ENROOTLOG"
   )

}

@test "run copies the script to run in CUSTOM_ENV_CI_WS first of all when enroot is involved" {
    # this is necessary because enroot will try to mount the file into the container
    # but the container runs on a compute node
    # and this means that the file needs to be on the global filesystem,
    # not in a random directory.
    # This is not necessary if the file is submitted directly
    # to the custom executor queue,
    # because in that case the script is copied for sure in CUSTOM_ENV_CI_WS.

   STEPNAME="${STEPS_IN_CONTAINER[0]}"
   ENROOTLOG="$MOCKLOGDIR"/enroot.log
   # cleanup
   rm -f "$ENROOTLOG"
   cat << EOF > "$TMP_PLAYGROUND/script-$STEPNAME".sh

touch "$TEST_PLAYGROUND"/script-output-"$STEPNAME".txt

EOF
   chmod +x "$TMP_PLAYGROUND/script-$STEPNAME".sh

   "$SRC/run.sh" enroot "$TMP_PLAYGROUND/script-$STEPNAME".sh "$STEPNAME" 3>/dev/null

   (
   # shellcheck source=./src/containerlib-enroot.sh
   source "$SRC/containerlib-enroot.sh"
   assert_file_contains "$ENROOTLOG" "start.*$CE_CONTAINER_NAME.*$CUSTOM_ENV_CI_WS/"
   )


}

# bats test_tags=termination
@test "run exit with error when slurm job has terminated, but script (in container) has not." {
    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    # shellcheck disable=SC1091,SC2031
    source "$CE_QUEUE_WORKSPACE/.env"
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"

    # shellcheck disable=SC2030
    STEP="${STEPS_IN_CONTAINER[0]}"
cat << EOF > script-"$STEP".sh

sleep 100

EOF
    chmod +x ./script-"$STEP".sh

    echo "Testing $STEP"

    (
    sleep 5
    # Terminating the
    stop_custom_executor_queue
    touch "$CUSTOM_ENV_CI_WS/cews_$CUSTOM_ENV_CI_JOB_ID"/terminated
    ) &

    run "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_line "Abnormal termination of Custom Executor Queue, exiting."


}

# bats test_tags=termination
@test "run exit with error when slurm job has terminated, but script (not in container) has not." {
    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    # shellcheck disable=SC1091,SC2031
    source "$CE_QUEUE_WORKSPACE/.env"
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"

    # shellcheck disable=SC2030
    STEP="${STEPS_OUT_CONTAINER[0]}"
cat << EOF > script-"$STEP".sh

sleep 100

EOF
    chmod +x ./script-"$STEP".sh

    echo "Testing $STEP"

    (
    sleep 5
    # Terminating the
    stop_custom_executor_queue
    touch "$CUSTOM_ENV_CI_WS/cews_$CUSTOM_ENV_CI_JOB_ID"/terminated
    ) &

    run "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_line "Abnormal termination of Custom Executor Queue, exiting."


}

# bats test_tags=serial
@test "when slurm job has terminated, output is displayed anyway." {
    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    # shellcheck disable=SC1091,SC2031
    source "$CE_QUEUE_WORKSPACE/.env"
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"

    # shellcheck disable=SC2030
    STEP="${STEPS_OUT_CONTAINER[0]}"
cat << EOF > script-"$STEP".sh
echo "This output should be visible"
sleep 100

EOF
    chmod +x ./script-"$STEP".sh

    echo "Testing $STEP"

    (
    sleep 20 # Very large for safety
    # Terminating the whole queue
    stop_custom_executor_queue
    touch "$CUSTOM_ENV_CI_WS/cews_0"/terminated
    ) &

    run "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"

    echo "Logfile:"
    echo "=============================="
    cat "$CUSTOM_EXECUTOR_QUEUE_LOGFILE"
    echo "=============================="
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_line "Abnormal termination of Custom Executor Queue, exiting."
    assert_line "This output should be visible"


}


@test "run exits with error if slurm custom executor queue is not running at submission time" {


    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    # shellcheck disable=SC1091,SC2031
    source "$CE_QUEUE_WORKSPACE/.env"
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"

    # shellcheck disable=SC2030
    STEP="${STEPS_OUT_CONTAINER[0]}"
cat << EOF > script-"$STEP".sh

echo "this should not run anyway"

EOF
    chmod +x ./script-"$STEP".sh

    echo "Testing $STEP"

    stop_custom_executor_queue

    run "$SRC"/run.sh enroot ./script-"$STEP".sh "$STEP"

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_line --regexp "ERROR: Custom executor queue process.*not running"

}


@test "run exits with error if not passed 3 arguments" {

    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

    STEP="a-step-name"
    # shellcheck disable=SC2031
    run "$SRC"/run.sh ./script-"$STEP".sh "$STEP"
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_line "Usage: run.sh <containerisation_backend> <script> <stepname>"

}

@test "run does not produce files out of CE_QUEUE_WORKSPACE" {

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh

    touch "$TEST_PLAYGROUND/enroot.log"

    ls "$TEST_PLAYGROUND" > files-before-run

    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    "$SRC/run.sh" enroot ./script.sh prepare_script

    ls "$TEST_PLAYGROUND" > files-after-run

    echo "Files before run:"
    cat files-before-run
    echo "Files after run:"
    cat files-after-run

    assert_equal "$(diff files-before-run files-after-run | wc -l )" 0

}

@test "run exits with error if the containerisation backend is not enroot, apptainer or none" {


    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh

    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    run "$SRC/run.sh" some-invalid-string ./script.sh prepare_script

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Invalid containerisation backend: some-invalid-string"

}



@test "run complains if 'none' is passed as an argument and CUSTOM_ENV_CI_JOB_IMAGE is used" {

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh
    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    #shellcheck disable=SC2031
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    run "$SRC/run.sh" none ./script.sh prepare_script
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Job requires a container image but 'none' selected as backend."
}

@test "run complains if 'none' is passed as an argument and CUSTOM_ENV_IMAGEFILE is used" {

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh
    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    #shellcheck disable=SC2031
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030
    export CUSTOM_ENV_IMAGEFILE="a-file.sif"
    run "$SRC/run.sh" none ./script.sh prepare_script
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Job requires a container image but 'none' selected as backend."
}

@test "if IMAGEFILE is defined (and CI_JOB_IMAGE is not), use that (apptainer)." {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh
    #shellcheck disable=SC2031
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="a-file.sif"
    run "$SRC/run.sh" apptainer ./script.sh prepare_script
    assert_success
    assert_file_contains "$MOCKLOGDIR"/apptainer.log "exec.*a-file.sif"


}

@test "if IMAGEFILE is defined (and CI_JOB_IMAGE is not), nothing changes for Enroot." {

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh
    #shellcheck disable=SC2031
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # shellcheck disable=SC2031
    export CUSTOM_ENV_IMAGEFILE="a-file.sqsh"
    run "$SRC/run.sh" enroot ./script.sh prepare_script
    assert_success
    ENROOTLOG="$MOCKLOGDIR"/enroot.log
    assert_exists "$ENROOTLOG"
    assert_file_contains "$MOCKLOGDIR"/enroot.log "start"

}


# bats test_tags=onlythis
@test "APPTAINER_EXEC_OPTIONS is passed to apptainer" {

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh
    #shellcheck disable=SC2031
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    export CUSTOM_ENV_APPTAINER_EXEC_OPTIONS="--some-options for-apptainer"
    run "$SRC/run.sh" apptainer ./script.sh prepare_script
    assert_success
    assert_exists "$MOCKLOGDIR"/apptainer.log
    assert_file_contains "$MOCKLOGDIR"/apptainer.log "exec.*$CUSTOM_ENV_APPTAINER_EXEC_OPTIONS"

}
