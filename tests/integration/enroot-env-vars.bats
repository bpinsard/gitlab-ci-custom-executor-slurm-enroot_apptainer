#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file(system) related asserts 
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading
    PATH="$PROJECT_ROOT/src:$PATH"

    TEST_PLAYGROUND="$PWD/$(mktemp -d configure-testXXXXXXX)"
    echo "Created test playground at $TEST_PLAYGROUND" >&3
    export ENROOT_RUNTIME_PATH="$TEST_PLAYGROUND/enroot/run"
    export ENROOT_CONFIG_PATH="$TEST_PLAYGROUND/enroot/conf"
    export ENROOT_CACHE_PATH="$TEST_PLAYGROUND/enroot/cache"
    export ENROOT_DATA_PATH="$TEST_PLAYGROUND/enroot/data"
    export ENROOT_TEMP_PATH="$TEST_PLAYGROUND/enroot/tmp"
    mkdir -p "$TEST_PLAYGROUND/enroot/tmp"
}

function teardown() {
    rm -rf "$TEST_PLAYGROUND"

}

@test "enroot does not use /run/user/" {

    rm -rf /run/user/$(id -u)/enroot
    rm alpine+latest.sqsh
    enroot import docker://alpine:latest
    enroot create --name alpine-enroot-test alpine+latest.sqsh
    
    rm -rf $HOME/.local/share/enroot/alpine-enroot-test
    assert_dir_not_exists $HOME/.local/share/enroot/alpine-enroot-test

    enroot start alpine-enroot-test grep PRETTY /etc/os-release


    assert_dir_not_exists /run/user/$(id -u)/enroot
}


