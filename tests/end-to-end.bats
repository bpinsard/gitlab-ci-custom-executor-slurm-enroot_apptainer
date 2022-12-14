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
    echo "Created test playground at $TEST_PLAYGROUND" >&3

    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit


    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 5 -n 1"
    export CUSTOM_ENV_CI_JOB_IMAGE="ubuntu:kinetic-20221101"
    export CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export SYSTEM_FALURE_EXIT_CODE=102
    export CUSTOM_ENV_CI_JOB_ID=54321

    }

function teardown() {
    if _on_horeka
    then
      echo rm -rf "$TEST_PLAYGROUND"
      rm -rf "$TEST_PLAYGROUND"
    fi
}


# bats test_tags=configure,cleanup,serial
@test "configure and cleanup" {

    "$SRC"/configure-slurm.sh  | "$JOB_ENV_READER" > ./job-env

    function _helper(){ squeue | grep -q "$CE_SLURM_JOB_ID"; }

    run _helper
    assert_success

    # shellcheck  disable=SC1091
    source ./job-env

    while ! scontrol wait_job "$CE_SLURM_JOB_ID"
    do
        sleep 1
    done
    # The image needs to be downloaded and the container set up
    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 90

    assert_file_exists "$CE_QUEUE_ENV_PATH"


    "$SRC"/cleanup-slurm.sh

    run _helper
    assert_failure




}

# bats test_tags=configure,cleanup,run,serial
@test "configure, run and cleanup run a simple script" {

    "$SRC"/configure-slurm.sh | "$JOB_ENV_READER" > ./job-env

    function _helper(){ squeue | grep -q "$CE_SLURM_JOB_ID"; }
    run _helper
    assert_success


    # shellcheck  disable=SC1091
    source ./job-env

    while ! scontrol wait_job "$CE_SLURM_JOB_ID"
    do
        sleep 1
    done
    # The image needs to be downloaded and the container set up
    wait_until_file_exists "$CE_QUEUE_ENV_PATH" 90

    assert_file_exists "$CE_QUEUE_ENV_PATH"


    cat <<EOF > "$STARTDIR"/get_sources_script.sh
echo "Cloning dummy repository..."
git clone https://github.com/mmesiti/test-repo-clone-me.git
EOF
    chmod +x "$STARTDIR"/get_sources_script.sh

    echo -n "Running get_sources... " >&3
    run "$SRC"/run.sh "$STARTDIR"/get_sources_script.sh get_sources
    echo "done." >&3

    assert_line "Cloning dummy repository..."

    cat <<EOF > "$STARTDIR"/build_script.sh

    echo "Doing a lot of work..."
    cd $CUSTOM_ENV_CI_BUILDS_DIR
    touch job-output.txt
    echo "Done."
EOF
    chmod +x "$STARTDIR"/build_script.sh

    echo -n "Running build_script... " >&3
    run "$SRC"/run.sh "$STARTDIR"/build_script.sh build_script
    echo "done. " >&3

    assert_line "Doing a lot of work..."
    assert_file_exists "$CUSTOM_ENV_CI_BUILDS_DIR"/job-output.txt

    "$SRC"/cleanup-slurm.sh


    run _helper
    assert_failure


}
