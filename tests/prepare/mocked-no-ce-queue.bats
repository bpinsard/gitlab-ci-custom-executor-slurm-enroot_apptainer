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
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit


    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42
    export CUSTOM_ENV_CI_JOB_ID=54321
    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_JOB_IMAGE=alpine:latest


    echo "Test setup phase completed."
}

function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
}


@test "prepare uses enroot when enroot is passed as first argument (no slurm)" {
    prepare.sh enroot noslurm

    assert_exists "$MOCKLOGDIR"/enroot.log

}

@test "prepare uses apptainer when apptainer is passed as first argument (no slurm)" {

    prepare.sh apptainer noslurm

    assert_exists "$MOCKLOGDIR"/apptainer.log

}

@test "prepare exits with error when CUSTOM_ENV_CI_JOB_IMAGE is set but enroot or apptainer are not passed as arguments (no slurm)" {

    #shellcheck disable=SC2030
    export SYSTEM_FAILURE_EXIT_CODE=102
    run prepare.sh none noslurm
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Job requires a container image but 'none' selected as backend."

}

@test "prepare communicates the containerisation backend if CE_DEBUG_LVL>0 (no slurm)" {
    (
    #shellcheck disable=SC2030,SC2031
    CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102

    export CUSTOM_ENV_CE_DEBUG_LVL=1
    run prepare.sh none noslurm
    assert_output --regexp "Containerisation backend: none"
    )
}

@test "prepare exits with error if the containerisation backend is not enroot, apptainer or none (no slurm)" {

    #shellcheck disable=SC2031,SC2030
    export SYSTEM_FAILURE_EXIT_CODE=102
    run prepare.sh some-random-string noslurm
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Invalid containerisation backend: some-random-string"

}

@test "prepare informs when both CUSTOM_ENV_{CI_JOB_IMAGE,IMAGEFILE} are specified (no slurm)" {

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE="an-image"
    #shellcheck disable=SC2030
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/a-file"
    run prepare.sh apptainer noslurm
    assert_success
    assert_output --regexp "image: an-image and variable IMAGEFILE=$CUSTOM_ENV_IMAGEFILE are set at the same time."

}

@test "prepare exit with error when image not speficied but IMAGEFILE is and file does not exist (no slurm)" {

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/a-file"
    #shellcheck disable=SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    run prepare.sh apptainer noslurm
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "IMAGEFILE=$CUSTOM_ENV_IMAGEFILE does not exist and image: not specified."

}

@test "when CUSTOM_ENV_IMAGEFILE is defined and exists, apptainer is not called at all (no slurm)" {

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/a-file"
    touch "$CUSTOM_ENV_IMAGEFILE"
    run prepare.sh apptainer noslurm
    assert_success
    if [ -f  "$MOCKLOGDIR"/apptainer.log ]
    then
       cat  "$MOCKLOGDIR"/apptainer.log
    fi
    assert_not_exist "$MOCKLOGDIR"/apptainer.log
}

@test "when CUSTOM_ENV_IMAGEFILE defined but not exist, call apptainer save image in IMAGEFILE (no slurm)" {

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE="an-image"
    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/a-file"
    run prepare.sh apptainer noslurm
    assert_success
    assert_exist "$MOCKLOGDIR"/apptainer.log
    cat "$MOCKLOGDIR"/apptainer.log
    assert_file_contains "$MOCKLOGDIR"/apptainer.log "pull.*$CUSTOM_ENV_IMAGEFILE.*$CUSTOM_ENV_CI_JOB_IMAGE"
}


@test "when CUSTOM_ENV_IMAGEFILE is defined and exists, enroot called only to create the container (no slurm)" {

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/a-file"
    touch "$CUSTOM_ENV_IMAGEFILE"
    run prepare.sh enroot noslurm
    assert_exist "$MOCKLOGDIR"/enroot.log
    assert_file_contains "$MOCKLOGDIR"/enroot.log "create --name .* $CUSTOM_ENV_IMAGEFILE"
    run cat "$MOCKLOGDIR"/enroot.log
    refute_output --partial "import"
}

@test "when CUSTOM_ENV_IMAGEFILE defined but not exist, enroot import to IMAGEFILE (no slurm)" {

    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_CI_JOB_IMAGE="an-image"
    #shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_IMAGEFILE="$TEST_PLAYGROUND/a-file"
    run prepare.sh enroot noslurm
    assert_exist "$MOCKLOGDIR"/enroot.log
    cat  "$MOCKLOGDIR"/enroot.log
    assert_file_contains "$MOCKLOGDIR"/enroot.log "import --output $CUSTOM_ENV_IMAGEFILE $CUSTOM_ENV_CI_JOB_IMAGE"
    assert_file_contains "$MOCKLOGDIR"/enroot.log "create --name GLCE_$CUSTOM_ENV_CI_JOB_ID $CUSTOM_ENV_IMAGEFILE"
}
