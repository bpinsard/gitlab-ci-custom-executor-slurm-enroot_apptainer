#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file-based operations
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    load_mocks
    SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/cleanup-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"

    export MOCKLOGDIR=$TEST_PLAYGROUND

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_IMAGE=docker://alpine:latest
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_DEFAULT_PARTITION=default-partition
    echo "Test setup phase completed."


    # shellcheck disable=SC1090
    source <( "$SRC/configure-slurm.sh" 3> /dev/null | read-job-env.py )

    (
        # shellcheck source=./src/enroot-containerlib.sh
        source "$SRC/enroot-containerlib.sh"
        mkdir "$MOCKLOGDIR/.enroot-fakecontainers"
        touch "$MOCKLOGDIR/.enroot-fakecontainers/$CE_CONTAINER_NAME"
    )


}

function teardown() {
    awk '{print $1}' "$MOCKLOGDIR"/pids.txt | xargs kill
    rm -rf "$TEST_PLAYGROUND"
    set +o nounset
    if [ -n "$CUSTOM_ENV_CE_DEBUG_DIR" ]
    then
        rm -r "$CUSTOM_ENV_CE_DEBUG_DIR/cews_*"
    fi
    set -o nounset
}

function teardown_file(){
    set +o nounset
    if [ -n "$CUSTOM_ENV_CE_DEBUG_DIR" ]
    then
    rm -r "$CUSTOM_ENV_CE_DEBUG_DIR"
    fi
    set -o nounset
}

@test "cleanup removes old custom executor queue workspaces" {

    # creating some fake workspaces,
    # with slurm jobs ids
    # that the squeue mock think are dead

    # This should be removed
    mkdir -p "$CUSTOM_ENV_CI_WS/cews_10"
    echo "declare -- CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=111111" >> "$CUSTOM_ENV_CI_WS/cews_10/.env"
    # This should stay
    mkdir -p "$CUSTOM_ENV_CI_WS/cews_11"
    echo "declare -- CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=34343434" >> "$CUSTOM_ENV_CI_WS/cews_11/.env"
    # This should be removed
    mkdir -p "$CUSTOM_ENV_CI_WS/cews_21"
    echo "declare -- CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=1111111" >> "$CUSTOM_ENV_CI_WS/cews_21/.env"


    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    "$SRC/cleanup-slurm.sh" enroot

    assert_dir_not_exists "$CUSTOM_ENV_CI_WS/cews_10"
    assert_dir_exists "$CUSTOM_ENV_CI_WS/cews_11"
    assert_dir_not_exists "$CUSTOM_ENV_CI_WS/cews_21"


}



@test "cleanup copies the CE queue workspaces to ~/ce-debug/cews_.../ if CUSTOM_ENV_CE_DEBUG is set" {

    # This should be removed
    mkdir -p "$CUSTOM_ENV_CI_WS/cews_10"
    echo "declare -- CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=111111" >> "$CUSTOM_ENV_CI_WS/cews_10/.env"
    # This should stay
    mkdir -p "$CUSTOM_ENV_CI_WS/cews_11"
    echo "declare -- CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=34343434" >> "$CUSTOM_ENV_CI_WS/cews_11/.env"
    # This should be removed
    mkdir -p "$CUSTOM_ENV_CI_WS/cews_21"
    echo "declare -- CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=1111111" >> "$CUSTOM_ENV_CI_WS/cews_21/.env"


    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CE_DEBUG=1
    "$SRC/cleanup-slurm.sh" enroot

    assert_dir_exists "$HOME/ce-debug/cews_10"
    assert_dir_not_exists "$HOME/ce-debug/cews_11"
    assert_dir_exists "$HOME/ce-debug/cews_21"


}

@test "cleanup should complain if the wrong backend is passed as an argument and image is used" {

    #shellcheck disable=SC2030
    export SYSTEM_FAILURE_EXIT_CODE=102
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    run "$SRC/cleanup-slurm.sh" nonexisting-backend
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Invalid containerisation backend: nonexisting-backend"
}

@test "cleanup should be happy if 'none' is passed as an argument and image is not used" {

    export CUSTOM_ENV_CI_JOB_IMAGE=""
    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    run "$SRC/cleanup-slurm.sh" none
    assert_success
}

@test "cleanup complains if 'none' is passed as an argument and image is used" {

    #shellcheck disable=SC2030,SC2031
    export SYSTEM_FAILURE_EXIT_CODE=102
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    run "$SRC/cleanup-slurm.sh" none
    assert_failure
    assert_equal "$status" "$SYSTEM_FAILURE_EXIT_CODE"
    assert_output --regexp "Error: Job requires a container image but 'none' selected as backend."
}



@test "cleanup scancels slurm job with SIGUSR1 if CUSTOM_ENV_KILL_SLURM is set to 1"  {
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10
    echo "declare -- CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=987654321" >> "$CE_QUEUE_WORKSPACE/.env"

    export CUSTOM_ENV_KILL_SLURM=1
    "$SRC/cleanup-slurm.sh" enroot

    assert_exists "$MOCKLOGDIR/scancel.log"
    cat "$MOCKLOGDIR/scancel.log"
    assert_file_contains "$MOCKLOGDIR/scancel.log" "ARGS: --batch --signal=SIGUSR1 -f 987654321"
    sleep 5 2
    assert_file_contains "$MOCKLOGDIR/scancel.log" "ARGS: 987654321"



}

@test "if CUSTOM_ENV_CE_DEBUG is set, save current WS"  {
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10
    echo "declare -- CUSTOM_EXECUTOR_QUEUE_SLURM_JOB_ID=34343434" >> "$CE_QUEUE_WORKSPACE/.env"

    # shellcheck disable=SC2031
    export CUSTOM_ENV_CE_DEBUG=1
    "$SRC/cleanup-slurm.sh" enroot

    assert_dir_exists "$HOME/ce-debug/cews_0"

}


@test "cleanup asks for cancellation of scripts that belong to current CI_JOB" {

    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10

    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE"/.env

    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    cat <<EOF > job.sh
sleep 100
EOF

    chmod +x ./job.sh


    TODONAME1="$(submit_to_custom_executor_queue ./job.sh JOB_"$CUSTOM_ENV_CI_JOB_ID")"
    TODONAME2="$(submit_to_custom_executor_queue ./job.sh JOB_"$CUSTOM_ENV_CI_JOB_ID")"

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    JOBSUBNAME1="$(basename "$TODONAME1")"
    JOBSUBNAME2="$(basename "$TODONAME2")"

    "$SRC/cleanup-slurm.sh" enroot

    # 2 seconds more for safety
    sleep "$CUSTOM_EXECUTOR_QUEUE_CYCLETIME" 2

    assert_not_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME1"
    assert_not_exists "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/PIDS/$JOBSUBNAME2"



}

@test "when CUSTOM_ENV_CI_JOB_IMAGE is not set, no errors (set to empty string)" {

    unset CUSTOM_ENV_CI_JOB_IMAGE
    wait_until_file_exists "$CE_QUEUE_WORKSPACE/.env" 10


    run "$SRC/cleanup-slurm.sh" enroot
    assert_success
    assert_not_exists "$MOCKLOGDIR/enroot.log"

}
