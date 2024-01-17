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
    
}

function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
    rm -r "$TMP_PLAYGROUND"

}

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

@test "run script should run its second argument (no ce queue)" {


    for STEP in "${STEPS_IN_CONTAINER[0]}" "${STEPS_OUT_CONTAINER[0]}"
    do
    echo "# testing $STEP..."
cat << EOF > script-"$STEP".sh

touch script-output-"$STEP".txt

EOF
    chmod +x ./script-"$STEP".sh

    "$SRC"/run.sh enroot noslurm ./script-"$STEP".sh "$STEP"

    assert_exists script-output-"$STEP".txt
    done

}

@test "run blocks until the script is executed (no ce queue)" {

    STEP="${STEPS_IN_CONTAINER[0]}"
    cat << EOF > script-"$STEP".sh
sleep 3
touch script-output-"$STEP".txt
EOF
    chmod +x ./script-"$STEP".sh

    "$SRC"/run.sh enroot noslurm ./script-"$STEP".sh "$STEP"
    assert_exists script-output-"$STEP".txt

}

@test "run outputs what the script outputs (no ce queue)." {

    for STEP in "${STEPS_IN_CONTAINER[0]}" "${STEPS_OUT_CONTAINER[0]}"
    do
cat << EOF > script-"$STEP".sh

echo "Hello from $STEP"

EOF
    chmod +x ./script-"$STEP".sh

    run "$SRC"/run.sh enroot noslurm ./script-"$STEP".sh "$STEP"

    assert_line "Hello from $STEP"
    done

}

@test "run exits with the same code as the script (no ce queue)." {
    # shellcheck disable=SC2030
    export SYSTEM_FAILURE_EXIT_CODE=102
    for STEP in "${STEPS_IN_CONTAINER[0]}" "${STEPS_OUT_CONTAINER[0]}"
    do
cat << EOF > script-"$STEP".sh

exit 42

EOF
    chmod +x ./script-"$STEP".sh

    echo "Testing $STEP"
    run "$SRC"/run.sh enroot noslurm ./script-"$STEP".sh "$STEP"
    assert_equal "$status" 42
    done

}

@test "run exits with \$SYSTEM_FAILURE_EXIT_CODE if an erroneus step name is given (no ce queue)" {

    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

cat << EOF > script.sh

echo "won't run"

EOF
    chmod +x ./script.sh

    run "$SRC/run.sh" enroot noslurm ./script.sh

    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"

}

@test "run succeeds even if CE_QUEUE_WORKSPACE is not defined (no ce queue)" {

    # shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

    (

    # shellcheck disable=SC2030
    export CE_QUEUE_WORKSPACE=""

cat << EOF > script.sh

echo "will run"

EOF
    chmod +x ./script.sh

    "$SRC/run.sh" enroot noslurm ./script.sh get_sources

    )


}

@test "run uses enroot for the steps \"in container\" if enroot is specified as first arg (no ce queue)" {

   STEPNAME="${STEPS_IN_CONTAINER[0]}"
   ENROOTLOG="$MOCKLOGDIR"/enroot.log
   # cleanup
   rm -f "$ENROOTLOG"
   cat << EOF > script-"$STEPNAME".sh

touch "$TEST_PLAYGROUND"/script-output-"$STEPNAME".txt

EOF
   chmod +x ./script-"$STEPNAME".sh

   "$SRC/run.sh" enroot noslurm ./script-"$STEPNAME".sh "$STEPNAME" 3>/dev/null

   assert_exists "$TEST_PLAYGROUND/script-output-$STEPNAME".txt
   assert_exists "$ENROOTLOG"

}

@test "run uses apptainer for the steps \"in container\" if apptainer is specified as first arg (no ce queue)" {

   STEPNAME="${STEPS_IN_CONTAINER[0]}"
   APPTAINERLOG="$MOCKLOGDIR"/apptainer.log
   # cleanup
   rm -f "$APPTAINERLOG"
   cat << EOF > script-"$STEPNAME".sh

touch "$TEST_PLAYGROUND"/script-output-"$STEPNAME".txt

EOF
   chmod +x ./script-"$STEPNAME".sh

   "$SRC/run.sh" apptainer noslurm ./script-"$STEPNAME".sh "$STEPNAME" 3>/dev/null

   assert_exists "$TEST_PLAYGROUND/script-output-$STEPNAME".txt
   assert_exists "$APPTAINERLOG"

}


@test "run does not run anything in a container if CUSTOM_ENV_CI_JOB_IMAGE not defined (no ce queue)" {

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
   "$SRC/run.sh" enroot noslurm ./script-"$STEPNAME".sh "$STEPNAME" 3>/dev/null
   assert_exists "$TEST_PLAYGROUND/script-output-$STEPNAME".txt
   assert_not_exists "$ENROOTLOG"
   )

}

@test "run copies the script to run in CUSTOM_ENV_CI_WS first of all when enroot is involved (no ce queue)" {
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

   "$SRC/run.sh" enroot noslurm "$TMP_PLAYGROUND/script-$STEPNAME".sh "$STEPNAME" 3>/dev/null

   (
   # shellcheck source=./src/containerlib-enroot.sh
   source "$SRC/containerlib-enroot.sh"
   assert_file_contains "$ENROOTLOG" "start.*$CE_CONTAINER_NAME.*$CUSTOM_ENV_CI_WS/"
   )


}

@test "run exits with error if the containerisation backend is not enroot, apptainer or none (no ce queue)" {


    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh

    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    run "$SRC/run.sh" some-invalid-string noslurm ./script.sh prepare_script

    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Invalid containerisation backend: some-invalid-string"

}



@test "run complains if 'none' is passed as an argument and CUSTOM_ENV_CI_JOB_IMAGE is used (no ce qeueue)" {

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh
    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

    run "$SRC/run.sh" none noslurm ./script.sh prepare_script
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Job requires a container image but 'none' selected as backend."
}

@test "run complains if 'none' is passed as an argument and CUSTOM_ENV_IMAGEFILE is used (no ce queue)" {

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh
    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030
    export CUSTOM_ENV_IMAGEFILE="a-file.sif"
    run "$SRC/run.sh" none noslurm ./script.sh prepare_script
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Job requires a container image but 'none' selected as backend."
}

@test "if IMAGEFILE is defined (and CI_JOB_IMAGE is not), use that (apptainer) (no ce queue)." {

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="a-file.sif"
    run "$SRC/run.sh" apptainer noslurm ./script.sh prepare_script
    assert_success
    assert_file_contains "$MOCKLOGDIR"/apptainer.log "exec.*a-file.sif"


}

@test "if IMAGEFILE is defined (and CI_JOB_IMAGE is not), nothing changes for Enroot. (no ce queue)" {

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh

    # shellcheck disable=SC2031
    export CUSTOM_ENV_IMAGEFILE="a-file.sqsh"
    run "$SRC/run.sh" enroot noslurm ./script.sh prepare_script
    assert_success
    ENROOTLOG="$MOCKLOGDIR"/enroot.log
    assert_exists "$ENROOTLOG"
    assert_file_contains "$MOCKLOGDIR"/enroot.log "start"

}


@test "APPTAINER_EXEC_OPTIONS is passed to apptainer (no ce queue)" {

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh

    export CUSTOM_ENV_APPTAINER_EXEC_OPTIONS="--some-options for-apptainer"
    run "$SRC/run.sh" apptainer noslurm ./script.sh prepare_script
    assert_success
    assert_exists "$MOCKLOGDIR"/apptainer.log
    assert_file_contains "$MOCKLOGDIR"/apptainer.log "exec.*$CUSTOM_ENV_APPTAINER_EXEC_OPTIONS"

}

@test "when 'noslurm' ls passed as an argument, no mention of custom executor queue in output" {

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh

    run "$SRC/run.sh" apptainer noslurm ./script.sh prepare_script
    refute_output --partial "custom executor queue"

}

@test "run does mention containerization backend, step and whether it uses slurm or not" {
    # This test is just easier to run without the custom executor queue

    cat <<EOF > script.sh
echo "hello"
EOF
    chmod +x ./script.sh

    run "$SRC/run.sh" apptainer noslurm ./script.sh prepare_script
    assert_output --regexp 'step:prepare_script'
    assert_output --regexp 'backend:apptainer'
    assert_output --regexp '(noslurm)'

}
