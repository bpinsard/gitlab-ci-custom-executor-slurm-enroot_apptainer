#!/usr/bin/env bash

function has_slurm_and_apptainer() {
    type -p srun &> /dev/null && type -p apptainer &> /dev/null

}


function setup() {
    load '../test_helper/bats-support/load' 
    load '../test_helper/bats-assert/load' 
    load '../test_helper/bats-file/load'
    load '../test-utils'

    has_slurm_and_apptainer || { echo "# slurm or apptainer executables not found, skipping" >&3 ; skip ;}

    TEST_PLAYGROUND="$PWD/apptainer-contract-test-$BATS_TEST_NAME"
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
@test "apptainer pull does not work on horeka login node" {
    # Unfortunately this is the case at the moment (20230129) 
    # Things seem to have been solved (20230616)
    skip

    HOSTNAME=$(hostname) # $HOSTNAME might not work
    # Make sure this runs on the login node
    [[ "$HOSTNAME" =~ hkn199[0-3]\.localdomain ]] || skip 

    # shellcheck disable=SC2030
    export APPTAINER_CACHEDIR="$TEST_PLAYGROUND/apptainer"
    run apptainer pull docker://alpine:latest
    assert_failure

}


# bats test_tags=pull,serial
@test "apptainer pull runs on the compute node, accept name for output image file and uses cache" {

    # shellcheck disable=SC2031
    export APPTAINER_CACHEDIR="$TEST_PLAYGROUND/apptainer"

    run srun -n 1 -p cpuonly  apptainer pull my-image.sif docker://alpine:latest

    assert_success
    assert_exists my-image.sif 
    assert_dir_exists "$APPTAINER_CACHEDIR"


}

# bats test_tags=run,serial
@test "apptainer executes file in PWD with --bind (exec no salloc)" {
    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  apptainer pull my-image.sif docker://alpine:latest
    SCR="$TEST_PLAYGROUND/script.sh"
    touch "$TEST_PLAYGROUND/afile"

    cat<<EOF > "$SCR"
#!/bin/sh
echo "This is a test message"
ls "$TEST_PLAYGROUND/afile"
EOF
    chmod +x "$SCR"


    # may run without a need for an allocation on horeka...
    # we need a bind just for safety,
    # because on HoreKa /home is symlinked to /hkfs/home.
    # Singularity only mounts /home by default
    # so if by any chance you are using paths in /hkfs/home/
    # they will not be seen inside the container.
    run apptainer exec --bind "$TEST_PLAYGROUND" my-image.sif "$SCR"
    assert_success

    assert_line "This is a test message"
    assert_line "$TEST_PLAYGROUND/afile"

}

# bats test_tags=run,serial
@test "apptainer sees PWD" {
    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  apptainer pull my-image.sif docker://alpine:latest

    # may run without a need for an allocation on horeka...
    # but might need a bind just for safety.
    run apptainer exec --bind "$TEST_PLAYGROUND" my-image.sif ls "$PWD"
    assert_success

}

# bats test_tags=run,serial
@test "apptainer scripts able to write on the host without --writable" {
    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  apptainer pull my-image.sif docker://alpine:latest
    SCR="$TEST_PLAYGROUND/script.sh"

    cat<<EOF > "$SCR"
#!/bin/sh
touch "$TEST_PLAYGROUND/afile"
EOF
    chmod +x "$SCR"

    #run srun -n 1 -p cpuonly apptainer exec my-image.sif "$SCR" 

    # using --bind may not be necessary on HoreKa, but:
    # we need a bind just for safety,
    # because on HoreKa /home is symlinked to /hkfs/home.
    # Singularity only mounts /home by default
    # so if by any chance you are using paths in /hkfs/home/
    # they will not be seen inside the container.
    # The use of --writable is involved and it is anyway possible
    # to write in the directories on the host.
        
    run apptainer exec --bind "$TEST_PLAYGROUND" my-image.sif "$SCR"

    assert_success
    assert_exists "$TEST_PLAYGROUND/afile"

}

# bats test_tags=coverage-problematic
@test "apptainer mounts single file in container and executes it without problems" {

    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  apptainer pull my-image.sif docker://alpine:latest
    SCR="$TEST_PLAYGROUND/script.sh"

    cat<<EOF > "$SCR"
#!/bin/sh
touch "$TEST_PLAYGROUND/afile"
EOF
    chmod +x "$SCR"

    #run srun -n 1 -p cpuonly apptainer exec my-image.sif "$SCR"
    # may run without a need for an allocation on horeka...
    run apptainer exec --bind "$SCR" my-image.sif "$SCR"

    assert_success

    assert_exists "$TEST_PLAYGROUND/afile"

}

# bats test_tags=coverage-problematic
@test "apptainer mounts directory and single file in directory in container and executes it without problems" {

    # we need an allocation for this, unfortunately.
    srun -n 1 -p cpuonly  apptainer pull my-image.sif docker://alpine:latest
    SCR="$TEST_PLAYGROUND/script.sh"

    cat<<EOF > "$SCR"
#!/bin/sh
touch "$TEST_PLAYGROUND/afile"
EOF
    chmod +x "$SCR"

    #run srun -n 1 -p cpuonly apptainer exec my-image.sif "$SCR"
    # may run without a need for an allocation on horeka...
    run apptainer exec --bind "$TEST_PLAYGROUND,$SCR" my-image.sif "$SCR"

    assert_success

    assert_exists "$TEST_PLAYGROUND/afile"

}
