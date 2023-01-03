#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output

    type -p enroot || { echo "# enroot executable not found, skipping" >&3 ; skip ;}


    TEST_PLAYGROUND="$PWD/enroot-contract-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    cd "$TEST_PLAYGROUND" || exit

}

function teardown() {
    yes | enroot remove alpine-enroot-test
    rm -f alpine+latest.sqsh
    rm -rf "$TEST_PLAYGROUND"

}

@test "enroot mounts single file in container and executes it without problems." {

    # shellcheck disable=SC2030
    export ENROOT_RUNTIME_PATH="$TEST_PLAYGROUND/enroot/run"
    # we do not change ENROOT_CONFIG_PATH
    # shellcheck disable=SC2030
    export ENROOT_CACHE_PATH="$TEST_PLAYGROUND/enroot/cache"
    # shellcheck disable=SC2030
    export ENROOT_DATA_PATH="$TEST_PLAYGROUND/enroot/data"

    rm -f alpine+latest.sqsh
    enroot import docker://alpine:latest
    # Will be in $ENROOT_DATA_PATH 
    enroot create --name alpine-enroot-test alpine+latest.sqsh
    
    SCR="$TEST_PLAYGROUND/script.sh"
    cat<<EOF > "$SCR"
#!/bin/sh
echo "This is a test message"
EOF
    chmod +x "$SCR"

    run enroot start --rw --mount "$SCR:$SCR" alpine-enroot-test "$SCR"

    assert_output "This is a test message"


}

@test "enroot CANNOT mount single file in container AND directory that contains it at the same time" {

    # shellcheck disable=SC2031
    export ENROOT_RUNTIME_PATH="$TEST_PLAYGROUND/enroot/run"
    # we do not change ENROOT_CONFIG_PATH
    # shellcheck disable=SC2031
    export ENROOT_CACHE_PATH="$TEST_PLAYGROUND/enroot/cache"
    # shellcheck disable=SC2031
    export ENROOT_DATA_PATH="$TEST_PLAYGROUND/enroot/data"

    rm -f alpine+latest.sqsh
    enroot import docker://alpine:latest
    # Will be in $ENROOT_DATA_PATH 
    enroot create --name alpine-enroot-test alpine+latest.sqsh
    
    SCR="$TEST_PLAYGROUND/script.sh"
    cat<<EOF > "$SCR"
#!/bin/sh
echo "This is a test message"
EOF
    chmod +x "$SCR"

    run enroot start --rw --mount "$TEST_PLAYGROUND:$TEST_PLAYGROUND,$SCR:$SCR" alpine-enroot-test "$SCR"

    assert_failure


}


