#!/usr/bin/env bash

setup(){

    load './test_helper/bats-support/load'
    load './test_helper/bats-assert/load'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"

    SRC="$PROJECT_ROOT"/src

    export CUSTOM_ENV_CI_WS="/a/dir/ectory"
    export CUSTOM_ENV_CI_JOB_IMAGE=docker://an-image:latest
    export CUSTOM_ENV_CI_JOB_ID=54321

}

teardown(){
    :

}

@test "if ENROOT_RUNTIME_PATH is already defined, do not redefine it" {


    # shellcheck disable=SC2030
    export ENROOT_RUNTIME_PATH="$CUSTOM_ENV_CI_WS/already/defined"

    # shellcheck source=./src/containerlib-enroot.sh
    source "$SRC"/containerlib-enroot.sh

    run echo "$ENROOT_RUNTIME_PATH"

    assert_line --partial "/already/defined"
    refute_line --partial "/.enroot/run"

}

@test "if ENROOT_CACHE_PATH is already defined, do not redefine it" {

    # shellcheck disable=SC2030,SC2031
    export ENROOT_CACHE_PATH="$CUSTOM_ENV_CI_WS/already/defined"

    # shellcheck source=./src/containerlib-enroot.sh
    source "$SRC"/containerlib-enroot.sh

    run echo "$ENROOT_CACHE_PATH"

    assert_line --partial "/already/defined"
    refute_line --partial "/.enroot/cache"

}

@test "if ENROOT_DATA_PATH is already defined, do not redefine it" {

    # shellcheck disable=SC2030,SC2031
    export ENROOT_DATA_PATH="$CUSTOM_ENV_CI_WS/already/defined"

    # shellcheck source=./src/containerlib-enroot.sh
    source "$SRC"/containerlib-enroot.sh

    run echo "$ENROOT_DATA_PATH"

    assert_line --partial "/already/defined"
    refute_line --partial "/.enroot/data"

}

@test "if \$CUSTOM_ENV_CI_JOB_IMAGE is not defined no var should be either" {


    (
        # shellcheck disable=SC2030
        export CUSTOM_ENV_CI_JOB_IMAGE=""

        # shellcheck source=./src/containerlib-enroot.sh
        source "$SRC"/containerlib-enroot.sh

        # shellcheck disable=SC2329
        function _helper() {
            # shellcheck disable=SC2317
            env | grep -cE '^ENROOT_.*_PATH'
        }

        run _helper
        assert_output 0
        set +o nounset
        assert [ -z "$CE_CONTAINER_NAME" ]
        set -o nounset
    )
}

@test "ENROOT_*_PATHS variables should be all inside CUSTOM_ENV_CI_WS" {

 # shellcheck source=./src/containerlib-enroot.sh
 source "$SRC"/containerlib-enroot.sh
 for VARNAME in ${!ENROOT*}
 do
     run echo "${!VARNAME}"
     assert_output --regexp "^$CUSTOM_ENV_CI_WS"
 done

}

@test "variable CE_CONTAINER_NAME contains CUSTOM_ENV_CI_JOB_ID" {


 # shellcheck source=./src/containerlib-enroot.sh
 source "$SRC"/containerlib-enroot.sh

 run echo "$CE_CONTAINER_NAME"
 assert_output --partial "$CUSTOM_ENV_CI_JOB_ID"

}

