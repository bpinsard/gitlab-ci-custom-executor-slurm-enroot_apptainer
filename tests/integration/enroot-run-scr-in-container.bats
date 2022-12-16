#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output

    type -p enroot || { echo "# enroot executable not found, skipping" >&3 ; skip ;}
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading

    TEST_PLAYGROUND="$PWD/$(mktemp -d configure-testXXXXXXX)"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3
    cd "$TEST_PLAYGROUND" || exit

}

function teardown() {
    yes | enroot remove alpine-enroot-test
    rm -f alpine+latest.sqsh
    rm -rf "$TEST_PLAYGROUND"

}

@test "enroot mounts single file in container and executes it without problems." {

    export ENROOT_RUNTIME_PATH="$TEST_PLAYGROUND/enroot/run"
    # we do not change ENROOT_CONFIG_PATH
    export ENROOT_CACHE_PATH="$TEST_PLAYGROUND/enroot/cache"
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


