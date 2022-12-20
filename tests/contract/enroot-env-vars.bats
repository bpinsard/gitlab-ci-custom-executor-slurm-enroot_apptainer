#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for file(system) related asserts 
    load '../test-utils'
    type -p enroot || { echo "# enroot executable not found, skipping" >&3 ; skip ;}
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading
    PATH="$PROJECT_ROOT/src:$PATH"

    TEST_PLAYGROUND="$PWD/$(mktemp -d enroot-env-var-testXXXXXXX)"
    echo "# Created test playground at $TEST_PLAYGROUND" >&3

}

function teardown() {
    rm -rf "$TEST_PLAYGROUND"
    rm -f alpine+latest.sqsh

}

@test "enroot does not use /run/user/ or $HOME/.local/share/enroot" {

    export ENROOT_RUNTIME_PATH="$TEST_PLAYGROUND/enroot/run"
    # we do not change ENROOT_CONFIG_PATH
    export ENROOT_CACHE_PATH="$TEST_PLAYGROUND/enroot/cache"
    export ENROOT_DATA_PATH="$TEST_PLAYGROUND/enroot/data"

    RUNDIR_DONTUSE=/run/user/$(id -u)/enroot
    CONTAINERDIR_DONTUSE=$HOME/.local/share/enroot/alpine-enroot-test

    rm -rf "$RUNDIR_DONTUSE" "$CONTAINERDIR_DONTUSE"
    # Cleanup before image download
    rm -f alpine+latest.sqsh

    enroot import docker://alpine:latest

    # Will be in $ENROOT_DATA_PATH 
    enroot create --name alpine-enroot-test alpine+latest.sqsh
    
    assert_dir_not_exists "$CONTAINERDIR_DONTUSE"

    enroot start alpine-enroot-test grep PRETTY /etc/os-release
    assert_dir_not_exists "$RUNDIR_DONTUSE"
}


