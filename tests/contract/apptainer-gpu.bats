#!/usr/bin/env bash

function get_gpu_test_jobid_file() {
    set +o nounset
    if [ -z "$CI_BUILDS_DIR" ]
    then
        echo "$HOME/.apptainer-gpu-test-jobid"
    else
        echo "$CI_BUILDS_DIR/.apptainer-gpu-test-jobid"
    fi
    set -o nounset
}

function setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file(system) related asserts 
    load '../test-utils'
    { type -p apptainer && type -p srun; } || { echo "# necessary executables not found, skipping" >&3 ; skip ;}

    TAG=12.1.1-devel-ubi8
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sif"

    TEST_PLAYGROUND="$PWD/test-apptainer-gpu-$BATS_TEST_NAME"
    create_dir_or_error_if_exists "$TEST_PLAYGROUND" 
    cp ./tests/contract/test.cu "$TEST_PLAYGROUND"
    cd "$TEST_PLAYGROUND" || exit

    read -r TEST_JOB_ID < "$(get_gpu_test_jobid_file)"
}

function setup_file() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file(system) related asserts
    load '../test-utils'
    { { type -p apptainer && type -p srun; } && {

    TAG=12.1.1-devel-ubi8
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sif"
    rm -rf "$IMAGEFILE"
    COMMAND=(apptainer pull "$IMAGEFILE" docker://nvidia/cuda:"$TAG")
    echo "${COMMAND[@]}" >&3
    "${COMMAND[@]}" >&3
    # TODO: accelerated might not be the best partition to use,
    #       but dev_accelerated is even more crowded.
    TEST_JOB_ID=$(sbatch --partition accelerated \
                         -t 3 \
                         --gres=gpu:1 \
                         --parsable \
                         -o "$HOME/.apptainer-gpu-test-job.out" \
                         --job-name 'apptainer-wrap' \
                         --wrap "sleep 150")
    echo "Submitted Job: $TEST_JOB_ID" >&3
    echo "$TEST_JOB_ID" > "$(get_gpu_test_jobid_file)"
    while ! scontrol wait_job "$TEST_JOB_ID" &> /dev/null
    do
        echo "Waiting for job to start..."
	sleep 5
    done

    } }|| { echo "# necessary executables not found, skipping" >&3; }
}

function teardown() {
   cd "$PROJECT_ROOT" && rm -rf "$TEST_PLAYGROUND" 
}


function teardown_file() {

    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file(system) related asserts
    load '../test-utils'
    { { type -p apptainer && type -p srun; } && {
    TAG=12.1.1-devel-ubi8
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sif"
    echo rm -rf "$IMAGEFILE" >&3
    rm -rf "$IMAGEFILE"
    read -r TEST_JOB_ID < "$(get_gpu_test_jobid_file)"
    echo scancel "$TEST_JOB_ID"
    scancel "$TEST_JOB_ID"
    rm "$(get_gpu_test_jobid_file)"
    rm "$HOME/.apptainer-gpu-test-job.out"
    } } || { echo "# necessary executables not found, skipping" >&3; }
}

# bats test_tags=skipped-local,nohang,slurmalloc
@test "apptainer gpu job fails without --nv" {
    COMMAND=(apptainer exec --bind '/scratch' "$IMAGEFILE" bash -c "nvcc -o tt ./test.cu && ./tt && echo ok")
    echo "${COMMAND[@]}" >&3
    run srun --jobid "$TEST_JOB_ID" "${COMMAND[@]}"
    assert_failure
    echo "$output"
    assert_equal "$status" 6 # ENXIO No such device or address
}

# bats test_tags=skipped-local,nohang,slurmalloc
@test "apptainer gpu job fails without monting /scratch" {
    COMMAND=(apptainer exec --nv "$IMAGEFILE" bash -c "nvcc -o tt ./test.cu && ./tt && echo ok")
    echo "${COMMAND[@]}" >&3
    run srun --jobid "$TEST_JOB_ID" "${COMMAND[@]}"
    echo "$output"
    assert_failure
    assert_equal "$status" 1 
    assert_output --regexp 'nvcc fatal\s+: Could not open output file'
}

# bats test_tags=skipped-local,nohang,slurmalloc
@test "apptainer gpu job works if --nv and /scratch are managed" {
    COMMAND=(apptainer exec --bind '/scratch' --nv "$IMAGEFILE" bash -c "nvcc -o tt ./test.cu && ./tt && echo ok")
    echo "${COMMAND[@]}" >&3
    srun --jobid "$TEST_JOB_ID" "${COMMAND[@]}"
}
