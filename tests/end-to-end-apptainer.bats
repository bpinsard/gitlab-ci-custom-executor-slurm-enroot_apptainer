#!/usr/bin/env bash

function has_slurm_and_apptainer(){
    which sbatch &> /dev/null && which apptainer &> /dev/null
}

function setup(){
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    load './test_helper/bats-file/load' # for assert_output and refute_output
    load './test-utils'
    has_slurm_and_apptainer || skip
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing and loading
    export SRC="$PROJECT_ROOT"/src

    JOB_ENV_READER="$PROJECT_ROOT"/tests/mocks/bin/read-job-env.py

    # shellcheck source=./src/include.sh
    source "$SRC/include.sh"

    TEST_PLAYGROUND="$PWD/end-to-end-test-apptainer-$BATS_TEST_NAME"
    assert_dir_not_exists "$TEST_PLAYGROUND"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"

    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    # export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit


    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 5 -n 1"
    export CUSTOM_ENV_CI_JOB_IMAGE="docker://ubuntu:kinetic-20221101"
    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export SYSTEM_FALURE_EXIT_CODE=102
    export CUSTOM_ENV_CI_JOB_ID=54321

    if [ -z "$CUSTOM_ENV_DEFAULT_PARTITION" ]
    then
      # If we are in a testing environment,
      # it might be that CUSTOM_ENV_DEFAULT_PARTITION is not defined
      # while DEFAULT_PARTITION is defined instead.
      export CUSTOM_ENV_DEFAULT_PARTITION="$DEFAULT_PARTITION"
    fi
    if [ -z "$CUSTOM_ENV_DEFAULT_PARTITION" ]
    then
      echo "Error:CUSTOM_ENV_DEFAULT_PARTITION not defined"
      exit 1
    fi

    export CUSTOM_ENV_KILL_SLURM=1
    }

function teardown() {
    if has_slurm_and_apptainer
    then
      echo rm -rf "$TEST_PLAYGROUND"
      rm -rf "$TEST_PLAYGROUND"
    fi
}


# bats test_tags=configure,prepare,cleanup
@test "configure, prepare, and cleanup" {

    "$SRC"/configure-slurm.sh  | "$JOB_ENV_READER" > ./job-env

    assert_exists ./job-env
    assert_file_contains ./job-env "CE_QUEUE_WORKSPACE"
    # shellcheck  disable=SC1091
    source ./job-env

    CE_SLURM_JOB_ID="$(get_slurm_jobid "$CE_QUEUE_WORKSPACE")"

    # shellcheck disable=SC2317
    function _helper(){ squeue | grep -q "$CE_SLURM_JOB_ID"; }

    run _helper
    assert_success

    assert_file_exists "$CE_QUEUE_WORKSPACE/.env"


    "$SRC"/prepare.sh apptainer

    "$SRC"/cleanup-slurm.sh apptainer

    run _helper
    assert_failure
}

# bats test_tags=configure,prepare,cleanup,run
@test "configure, prepare, run and cleanup run a simple script" {

    "$SRC"/configure-slurm.sh | "$JOB_ENV_READER" > ./job-env

    assert_exists ./job-env
    assert_file_contains ./job-env "CE_QUEUE_WORKSPACE"
    # shellcheck  disable=SC1091
    source ./job-env

    CE_SLURM_JOB_ID="$(get_slurm_jobid "$CE_QUEUE_WORKSPACE")"

    function _helper(){ squeue | grep -q "$CE_SLURM_JOB_ID"; }
    run _helper
    assert_success


    assert_file_exists "$CE_QUEUE_WORKSPACE/.env"

    echo -n "# Preparing job... " >&3
    "$SRC"/prepare.sh apptainer
    echo "done." >&3
    assert_dir_exists "$CUSTOM_ENV_CI_WS/.apptainer"

    cat <<EOF > "$STARTDIR"/get_sources_script.sh
#!/bin/bash
echo "Cloning dummy repository..."
git clone https://github.com/mmesiti/test-repo-clone-me.git
EOF
    chmod +x "$STARTDIR"/get_sources_script.sh

    echo -n "# Running get_sources... " >&3
    run "$SRC"/run.sh apptainer "$STARTDIR"/get_sources_script.sh get_sources
    echo "done." >&3

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

    echo -n "# Running build_script... " >&3
    run "$SRC"/run.sh apptainer "$STARTDIR"/build_script.sh build_script
    echo "done." >&3

    assert_line "Doing a lot of work..."
    assert_file_exists "$CUSTOM_ENV_CI_WS"/job-output.txt

    "$SRC"/cleanup-slurm.sh apptainer

    # Check that the slurm job is over
    run _helper
    assert_failure

}
