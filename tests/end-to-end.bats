#!/usr/bin/env bash

function setup(){
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    load './test_helper/bats-file/load' # for assert_output and refute_output
    load './test-utils'
    _on_horeka || skip
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    export SRC="$PROJECT_ROOT"/src

    JOB_ENV_READER="$PROJECT_ROOT"/tests/mocks/bin/read-job-env.py

    TEST_PLAYGROUND="$PWD/$(mktemp -d end-to-end-testXXXXXXX)"
    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit


    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 3 -n 1"
    export CUSTOM_ENV_CI_JOB_IMAGE="ubuntu:kinetic-20221101"
    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"

    }

function teardown() {
    if _on_horeka
    then
      echo rm -r "$TEST_PLAYGROUND"
      rm -r "$TEST_PLAYGROUND"
    fi
}

@test "configure and cleanup" {
    skip # DEBUG , still flaky



    "$SRC"/configure-slurm.sh  | "$JOB_ENV_READER" > ./job-env

    #function _helper_pre(){ squeue | grep -q "$CE_SLURM_JOB_ID" }

    #run _helper_pre
    #assert_success

    source ./job-env

    while ! scontrol wait_job "$CE_SLURM_JOB_ID"
    do
        sleep 1
    done
    wait_until_file_exists "$CE_CUSTOM_EXECUTOR_QUEUE_ENV_PATH" 30


    "$SRC"/cleanup-slurm.sh

    #function _helper_post(){ squeue | grep -q "$CE_SLURM_JOB_ID" }
    #run _helper_post
    #assert_failure




}

#@test "configure, run and cleanup run a simple script" {
#
#    skip
#
#    "$SRC"/configure-slurm.sh | "$JOB_ENV_READER" > ./job-env
#    #assert  (squeue | grep -q "$CE_SLURM_JOB_ID" )
#
#
#    source ./job-env
#
#    cat <<EOF > "$STARTDIR"/get_sources_script.sh
#echo "Cloning dummy repository..."
#git clone https://github.com/mmesiti/test-repo-clone-me.git
#EOF
#
#    run "$SRC"/run.sh "$STARTDIR"/get_sources_script.sh get_sources
#
#    assert_line "Cloning dummy repository..."
#
#    cat <<EOF > "$STARTDIR"/build_script.sh
#
#    echo "Doing a lot of work..."
#    cd $CUSTOM_ENV_CI_BUILDS_DIR
#    touch job-output.txt
#    echo "Done."
#EOF
#
#    run "$SRC"/run.sh "$STARTDIR"/build_script.sh build_script
#
#    assert_line "Doing a lot of work..."
#    assert_file_exists "$CUSTOM_ENV_CI_BUILDS_DIR"/job-output.txt
#
#    "$SRC"/cleanup-slurm.sh
#
#
#    #assert [ ! ( squeue | grep -q "$CE_SLURM_JOB_ID" ) ]
#
#}
