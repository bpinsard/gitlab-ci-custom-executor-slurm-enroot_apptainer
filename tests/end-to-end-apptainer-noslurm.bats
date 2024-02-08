#!/usr/bin/env bash

function has_apptainer(){
    which apptainer &> /dev/null
}

function setup(){
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    load './test_helper/bats-file/load' # for assert_output and refute_output
    load './test-utils'
    has_apptainer || skip
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing and loading
    export SRC="$PROJECT_ROOT"/src

    JOB_ENV_READER="$PROJECT_ROOT"/tests/mocks/bin/read-job-env.py

    # shellcheck source=./src/slurm-include.sh
    source "$SRC/slurm-include.sh"

    TEST_PLAYGROUND="$PWD/end-to-end-test-apptainer-$BATS_TEST_NAME"
    assert_dir_not_exists "$TEST_PLAYGROUND"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"

    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    export CUSTOM_ENV_CI_JOB_IMAGE="docker://ubuntu:kinetic-20221101"

    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND/ci-ws"; mkdir -p "$CUSTOM_ENV_CI_WS"
    export CUSTOM_ENV_CI_CONCURRENT_ID=42

    export SYSTEM_FALURE_EXIT_CODE=102
    export CUSTOM_ENV_CI_JOB_ID=54321

    }

function teardown() {
    if has_apptainer
    then
      echo rm -rf "$TEST_PLAYGROUND"
      rm -rf "$TEST_PLAYGROUND"
    fi
}


# bats test_tags=configure,prepare,cleanup
@test "configure, prepare, and cleanup (noslurm)" {

    "$SRC"/configure.sh apptainer noslurm | "$JOB_ENV_READER" > ./job-env

    assert_exists ./job-env
    # shellcheck  disable=SC1091
    source ./job-env

    "$SRC"/prepare.sh apptainer noslurm

    "$SRC"/cleanup.sh apptainer noslurm

}

# bats test_tags=configure,prepare,cleanup,run
@test "configure, prepare, run and cleanup run a simple script (noslurm)" {

    "$SRC"/configure.sh apptainer noslurm | "$JOB_ENV_READER" > ./job-env

    assert_exists ./job-env
    # shellcheck  disable=SC1091
    source ./job-env

    echo "Preparing job... "
    "$SRC"/prepare.sh apptainer noslurm
    echo "done."
    assert_dir_exists "$CUSTOM_ENV_CI_WS/.apptainer"

    cat <<EOF > "$STARTDIR"/get_sources_script.sh
#!/bin/bash
echo "Cloning dummy repository..."
git clone https://github.com/mmesiti/test-repo-clone-me.git
EOF
    chmod +x "$STARTDIR"/get_sources_script.sh

    echo "Running get_sources... "
    run "$SRC"/run.sh apptainer noslurm "$STARTDIR"/get_sources_script.sh get_sources
    echo "done."

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
    run "$SRC"/run.sh apptainer noslurm "$STARTDIR"/build_script.sh build_script
    echo "done."

    assert_success
    assert_line "Doing a lot of work..."
    assert_file_exists "$CUSTOM_ENV_CI_WS"/job-output.txt

    "$SRC"/cleanup.sh apptainer noslurm

}
