#!/usr/bin/env bash

function has_slurm_and_enroot(){
    which sbatch &> /dev/null && which enroot &> /dev/null
}

function get_slurm_default_partition() {
    scontrol show partition | grep -e "dev_\(single\|cpuonly\)" | cut -d= -f2
}

function setup(){
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    load './test_helper/bats-file/load' # for assert_output and refute_output
    load './test-utils'
    has_slurm_and_enroot || skip
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    export SRC="$PROJECT_ROOT"/src

    JOB_ENV_READER="$PROJECT_ROOT"/tests/mocks/bin/read-job-env.py

    # shellcheck source=./src/slurm-include.sh
    source "$SRC/slurm-include.sh"

    TEST_PLAYGROUND="$PWD/end-to-end-test-enroot-$BATS_TEST_NAME"
    assert_dir_not_exists "$TEST_PLAYGROUND"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"

    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    # export CUSTOM_ENV_CE_DEBUG_LVL=2
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    SLURM_DEFAULT_PARTITION=$(get_slurm_default_partition)
    export SLURM_DEFAULT_PARTITION

    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=$SLURM_DEFAULT_PARTITION -t 5 -n 1"
    export CUSTOM_ENV_CI_JOB_IMAGE="docker://ubuntu:kinetic-20221101"

    export SYSTEM_FALURE_EXIT_CODE=102
    export CUSTOM_ENV_CI_JOB_ID=54321

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci-ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42

    if [ -z "$CUSTOM_ENV_DEFAULT_PARTITION" ]
    then
      # If we are in a testing environment,
      # it might be that CUSTOM_ENV_DEFAULT_PARTITION is not defined
      # while DEFAULT_PARTITION is defined instead.
      export CUSTOM_ENV_DEFAULT_PARTITION="$DEFAULT_PARTITION"
    fi
    if [ -z "$CUSTOM_ENV_DEFAULT_PARTITION" ]
    then
      export CUSTOM_ENV_DEFAULT_PARTITION="$SLURM_DEFAULT_PARTITION"
    fi
    if [ -z "$CUSTOM_ENV_DEFAULT_PARTITION" ]
    then
      echo "Error:CUSTOM_ENV_DEFAULT_PARTITION not defined"
      exit 1
    fi

    export CUSTOM_ENV_KILL_SLURM=1

    setup_allowed_gitlab_users_file
}

function teardown() {
    if has_slurm_and_enroot
    then
      echo rm -rf "$TEST_PLAYGROUND"
      rm -rf "$TEST_PLAYGROUND"
    fi
}


# bats test_tags=configure,prepare,cleanup
@test "configure, prepare, and cleanup" {

    "$SRC"/configure.sh enroot useslurm | "$JOB_ENV_READER" > ./job-env

    assert_exists ./job-env
    assert_file_contains ./job-env "CE_QUEUE_WORKSPACE"
    # shellcheck  disable=SC1091
    source ./job-env

    CE_SLURM_JOB_ID="$(get_slurm_jobid "$CE_QUEUE_WORKSPACE")"
    function is_job_in_squeue_output(){ squeue | grep "$CE_SLURM_JOB_ID"; }
    is_job_in_squeue_output

    # shellcheck disable=SC2317

    assert_file_exists "$CE_QUEUE_WORKSPACE/.env"


    "$SRC"/prepare.sh enroot useslurm

    "$SRC"/cleanup.sh enroot useslurm

    # Check that the slurm job is over
    squeue > squeue-output.txt
    function is_job_not_in_file(){ ! grep -q "$CE_SLURM_JOB_ID" squeue-output.txt; }
    function is_job_completing() { grep "$CE_SLURM_JOB_ID" squeue-output.txt | grep -qw 'CG' ; }
    is_job_not_in_file || is_job_completing
}

# bats test_tags=configure,prepare,cleanup,run
@test "configure, prepare, run and cleanup run a simple script" {

    "$SRC"/configure.sh enroot useslurm | "$JOB_ENV_READER" > ./job-env

    assert_exists ./job-env
    assert_file_contains ./job-env "CE_QUEUE_WORKSPACE"
    # shellcheck  disable=SC1091
    source ./job-env

    CE_SLURM_JOB_ID="$(get_slurm_jobid "$CE_QUEUE_WORKSPACE")"

    function is_job_in_squeue_output(){ squeue | grep "$CE_SLURM_JOB_ID"; }
    is_job_in_squeue_output

    assert_file_exists "$CE_QUEUE_WORKSPACE/.env"

    echo "Preparing job... "
    "$SRC"/prepare.sh enroot useslurm
    echo "done."
    assert_dir_exists "$CUSTOM_ENV_CI_WS/.enroot"

    cat <<EOF > "$STARTDIR"/get_sources_script.sh
#!/bin/bash
echo "Cloning dummy repository..."
git clone https://github.com/mmesiti/test-repo-clone-me.git
EOF
    chmod +x "$STARTDIR"/get_sources_script.sh

    echo "Running get_sources... "
    run "$SRC"/run.sh enroot useslurm "$STARTDIR"/get_sources_script.sh get_sources
    echo "done."

    echo "Job log - after get-sources:"
    echo "============================="
    cat  "$CE_QUEUE_WORKSPACE/log.txt"
    echo "============================="

    echo "Output from job, as seen by run:"
    echo "============================="
    echo "$output"
    echo "============================="

    echo "Content of the queue workspace "
    echo "============================="
    ( cd "$CE_QUEUE_WORKSPACE" && find . )
    echo "============================="

    assert_success
    assert_line "Cloning dummy repository..."

    cat <<EOF > "$STARTDIR"/build_script.sh
#!/bin/bash
echo "Doing a lot of work..."
pwd
cd $CUSTOM_ENV_CI_WS
touch $CUSTOM_ENV_CI_WS/job-output.txt
echo "Done."
EOF
    chmod +x "$STARTDIR"/build_script.sh

    echo "Running build_script... "
    run "$SRC"/run.sh enroot useslurm "$STARTDIR"/build_script.sh build_script
    echo "done."

    echo "Job log - after build-script:"
    echo "============================="
    cat  "$CE_QUEUE_WORKSPACE/log.txt"
    echo "============================="
    assert_success
    assert_line "Doing a lot of work..."
    assert_file_exists "$CUSTOM_ENV_CI_WS"/job-output.txt

    "$SRC"/cleanup.sh enroot useslurm

    # Check that the slurm job is over
    squeue > squeue-output.txt
    function is_job_not_in_file(){ ! grep -q "$CE_SLURM_JOB_ID" squeue-output.txt; }
    function is_job_completing() { grep "$CE_SLURM_JOB_ID" squeue-output.txt | grep -qw 'CG' ; }
    is_job_not_in_file || is_job_completing

}
