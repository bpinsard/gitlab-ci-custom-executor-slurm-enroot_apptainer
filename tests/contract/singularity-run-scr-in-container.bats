#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' 
    load '../test_helper/bats-assert/load' 
    load '../test_helper/bats-file/load'
    load '../test-utils'

    _on_horeka || skip
    type -p singularity || { echo "# singularity executable not found, skipping" >&3 ; skip ;}



    TEST_PLAYGROUND="$PWD/singularity-contract-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    cd "$TEST_PLAYGROUND" || exit

    # DEBUG
    env > "$HOME/$BATS_TEST_NAME.env"

}

function teardown() {
    rm -f alpine.sif
    rm -rf "$TEST_PLAYGROUND"

}

# bats test_tags=pullfail,serial
@test "singularity pull does not work on horeka login node" {
    # Unfortunately this is the case at the moment (20230129) 

    HOSTNAME=$(hostname) # $HOSTNAME might not work
    # Make sure this runs on the login node
    [[ "$HOSTNAME" =~ hkn199[0-3]\.localdomain ]] || skip 

    # shellcheck disable=SC2030
    export SINGULARITY_CACHEDIR="$TEST_PLAYGROUND/singularity"
    run singularity pull docker://alpine:latest
    assert_failure

}


# bats test_tags=pull,serial
@test "singularity pull runs on the compute node, accept name for output image file and uses cache" {

    # shellcheck disable=SC2031
    export SINGULARITY_CACHEDIR="$TEST_PLAYGROUND/singularity"

    run srun -n 1 -p cpuonly  singularity pull my-image.sif docker://alpine:latest

    assert_success
    assert_exists my-image.sif 
    assert_dir_exists "$SINGULARITY_CACHEDIR"


}

# bats test_tags=run,serial
@test "singularity executes file in PWD without bind (exec no salloc)" {
    # This may depend on the default binds in /etc/singularity/singularity.conf
    cd "$TEST_PLAYGROUND"
    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  singularity pull my-image.sif docker://alpine:latest
    SCR="$TEST_PLAYGROUND/script.sh"
    touch "$TEST_PLAYGROUND/afile"

    cat<<EOF > "$SCR"
#!/bin/sh
echo "This is a test message"
ls "$TEST_PLAYGROUND/afile"
EOF
    chmod +x "$SCR"


    # may run without a need for an allocation on horeka...
    run singularity exec my-image.sif "$SCR" 
    assert_success

    assert_line "This is a test message"
    assert_line "$TEST_PLAYGROUND/afile"


}

# bats test_tags=run,serial
@test "singularity sees PWD" {
    # This may depend on the default binds in /etc/singularity/singularity.conf
    cd "$TEST_PLAYGROUND"
    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  singularity pull my-image.sif docker://alpine:latest

    # may run without a need for an allocation on horeka...
    run singularity exec my-image.sif ls "$PWD"
    assert_success

}

# bats test_tags=run,serial
@test "singularity sees HOME" {
    # This may depend on the default binds in /etc/singularity/singularity.conf
    cd "$TEST_PLAYGROUND"
    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  singularity pull my-image.sif docker://alpine:latest

    # may run without a need for an allocation on horeka...
    run singularity exec my-image.sif ls "$HOME"
    assert_success

}

# bats test_tags=serial
@test "singularity sees directory hierarchy in Home" {

    cd "$TEST_PLAYGROUND"
    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  singularity pull my-image.sif docker://alpine:latest

    # Not to overwrite HOME
    HOME2="/hkfs/home/project/hk-project-scs/hs2454/"

    echo "id in container:"
    singularity exec my-image.sif id
    echo "pwd in container:"
    singularity exec my-image.sif pwd
    echo "test playground: $TEST_PLAYGROUND"
    echo "home: $HOME"
    echo "home content in container:"
    singularity exec my-image.sif ls "$HOME"
    echo "home: $HOME2"
    REPO="$DIR2/0/sspe/custom-executor-slurm-enroot/"
    assert_success


}


# bats test_tags=run,serial
@test "singularity scripts able to write on the host" {
    # This may depend on the default binds in /etc/singularity/singularity.conf
    cd "$TEST_PLAYGROUND"
    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  singularity pull my-image.sif docker://alpine:latest
    SCR="$TEST_PLAYGROUND/script.sh"

    cat<<EOF > "$SCR"
#!/bin/sh
touch "$TEST_PLAYGROUND/afile"
EOF
    chmod +x "$SCR"

    #run srun -n 1 -p cpuonly singularity exec my-image.sif "$SCR" 
    # may run without a need for an allocation on horeka...
    run singularity exec my-image.sif "$SCR" 

    assert_success

    assert_exists "$TEST_PLAYGROUND/afile"


}

