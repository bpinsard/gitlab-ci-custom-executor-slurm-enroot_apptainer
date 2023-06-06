#!/usr/bin/env bash

function setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file(system) related asserts 
    load '../test-utils'

    TAG=12.1.1-devel-ubi8
    { type -p apptainer && type -p srun; } || { echo "# necessary executables not found, skipping" >&3 ; skip ;}
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sif"

    TEST_PLAYGROUND="$PWD/test-apptainer-gpu-$BATS_TEST_NAME"
    mkdir "$TEST_PLAYGROUND" 
    cp ./tests/contract/test.cu "$TEST_PLAYGROUND"
    cd "$TEST_PLAYGROUND" || exit

    read -r JOB_ID < "$HOME/.apptainer-gpu-test-jobid"
}

function setup_file() {
    TAG=12.1.1-devel-ubi8
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sif"
    rm -rf "$IMAGEFILE"
    COMMAND=(apptainer pull "$IMAGEFILE" docker://nvidia/cuda:"$TAG")
    echo "${COMMAND[@]}" >&3
    "${COMMAND[@]}" >&3
    JOB_ID=$(sbatch --partition accelerated \
	            -t 3 \
		    --gres=gpu:1 \
		    --parsable \
		    -o "$HOME/.apptainer-gpu-test-job.out" \
                    --wrap "sleep 150")
    echo "Submitted Job: $JOB_ID" >&3
    echo "$JOB_ID" > "$HOME/.apptainer-gpu-test-jobid"
    while ! scontrol wait_job "$JOB_ID" &> /dev/null
    do
        echo "Waiting for job to start..."
	sleep 5
    done

}

function teardown() {
   cd "$PROJECT_ROOT" && rm -rf "$TEST_PLAYGROUND" 
}


function teardown_file() {
    TAG=12.1.1-devel-ubi8
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sif"
    echo rm -rf "$IMAGEFILE" >&3
    rm -rf "$IMAGEFILE"
    echo scancel "$JOB_ID"
    scancel "$JOB_ID"
    echo rm "$HOME/.apptainer-gpu-test-jobid"
    rm "$HOME/.apptainer-gpu-test-jobid"
    rm "$HOME/.apptainer-gpu-test-job.out"
}


@test "apptainer gpu job fails without --nv" {
    COMMAND=(apptainer exec --bind "$TMPDIR" "$IMAGEFILE" bash -c "nvcc -o tt ./test.cu && ./tt && echo ok")
    echo "${COMMAND[@]}" >&3
    run srun --jobid "$JOB_ID" "${COMMAND[@]}"
    assert_failure
    echo "$output"
    assert_equal "$status" 6 # ENXIO No such device or address
}

@test "apptainer gpu job fails without monting TMPDIR" { 
    COMMAND=(apptainer exec --nv "$IMAGEFILE" bash -c "nvcc -o tt ./test.cu && ./tt && echo ok")
    echo "${COMMAND[@]}" >&3
    run srun --jobid "$JOB_ID" "${COMMAND[@]}"
    echo "$output"
    assert_failure
    assert_equal "$status" 1 
    assert_output --regexp 'nvcc fatal\s+: Could not open output file'
}

@test "apptainer gpu job works if --nv and TMPDIR are managed" { 
    COMMAND=(apptainer exec --bind "$TMPDIR" --nv "$IMAGEFILE" bash -c "nvcc -o tt ./test.cu && ./tt && echo ok")
    echo "${COMMAND[@]}" >&3
    srun --jobid "$JOB_ID" "${COMMAND[@]}"
}
