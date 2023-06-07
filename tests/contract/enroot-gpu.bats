#!/usr/bin/env bash

function setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file(system) related asserts 
    load '../test-utils'

    { type -p enroot && type -p srun; } || { echo "# necessary executables not found, skipping" >&3 ; skip ;}
    TAG=12.1.1-devel-ubi8
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sqsh"

    # We do not touch other enroot variables
    export ENROOT_RUNTIME_PATH="$PROJECT_ROOT/enroot-test/enroot/run"

    TEST_PLAYGROUND="$PWD/test-enroot-gpu-$BATS_TEST_NAME"
    mkdir "$TEST_PLAYGROUND" 
    cp ./tests/contract/test.cu "$TEST_PLAYGROUND"
    cd "$TEST_PLAYGROUND" || exit

    read -r ENROOT_TEST_JOB_ID < "$HOME/.enroot-gpu-test-jobid"
}

function setup_file() {
    TAG=12.1.1-devel-ubi8
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sqsh"
    rm -rf "$IMAGEFILE"

    # We do not touch other enroot variables
    export ENROOT_RUNTIME_PATH="$PROJECT_ROOT/enroot-test/enroot/run"
    mkdir -p "$ENROOT_RUNTIME_PATH"

    COMMAND=(enroot import --output "$IMAGEFILE" docker://nvidia/cuda:"$TAG")
    echo "${COMMAND[@]}" >&3
    "${COMMAND[@]}" >&3
    
    COMMAND=(enroot create --name enroot-gpu-test-container "$IMAGEFILE" )
    echo "${COMMAND[@]}" >&3
    "${COMMAND[@]}" >&3
    ENROOT_TEST_JOB_ID=$(sbatch --partition accelerated \
                                -t 3 \
                                --gres=gpu:1 \
                                --parsable \
                                -o "$HOME/.enroot-gpu-test-job.out" \
                                --wrap "sleep 150")
    echo "Submitted Job: $ENROOT_TEST_JOB_ID" >&3
    echo "$ENROOT_TEST_JOB_ID" > "$HOME/.enroot-gpu-test-jobid"
    while ! scontrol wait_job "$ENROOT_TEST_JOB_ID" &> /dev/null
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
    IMAGEFILE="$PROJECT_ROOT/cuda_$TAG.sqsh"

    echo rm -rf "$IMAGEFILE" >&3
    rm -rf "$IMAGEFILE"
    echo scancel "$ENROOT_TEST_JOB_ID"
    scancel "$ENROOT_TEST_JOB_ID"
    echo rm "$HOME/.enroot-gpu-test-jobid"
    rm "$HOME/.enroot-gpu-test-jobid"
    rm "$HOME/.enroot-gpu-test-job.out"
    yes | enroot remove enroot-gpu-test-container
}


@test "enroot gpu job works without monting /scratch" { 
    COMMAND=(enroot start --mount "$PWD:$PWD" enroot-gpu-test-container bash -c "cd $PWD && nvcc -o tt ./test.cu && ./tt && echo ok")
    echo "${COMMAND[@]}" >&3
    srun --jobid "$ENROOT_TEST_JOB_ID" "${COMMAND[@]}"
}

