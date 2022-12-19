#!/usr/bin/env bash

setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for assert_output and refute_output
    load '../test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT

    load_mocks
    TEST_PLAYGROUND=$PWD/$(mktemp -d enroot-mock-testXXXXXXX)
    echo "Created test playground at $TEST_PLAYGROUND" >&3
    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
    echo "Created test playground at $TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

    export ENROOT_MOCK_PATH=/some/path
}

teardown() {

    rm -r "$TEST_PLAYGROUND"

}
@test "enroot mock complains if no log location is given" {

    (
    # shellcheck disable=SC2030
    export MOCKLOGDIR=
    run enroot --something
    assert_equal "$status" 45
    )

}


@test "enroot mock record logs at given location" {

    enroot --something
    # shellcheck disable=SC2031
    assert_file_exists "$MOCKLOGDIR"/enroot.log

}

@test "enroot mock records ENROOT* environment variables" {


    export ENROOT_SOME_PATH=/test/path

    enroot --something

    # shellcheck disable=SC2031
    run cat "$MOCKLOGDIR"/enroot.log
    assert_line --partial "ENROOT_SOME_PATH"

}

@test "enroot mock records its stdin when using remove" {


    enroot remove thisthing < <(echo "some kind of input")

    # shellcheck disable=SC2031
    run cat "$MOCKLOGDIR"/enroot.log
    assert_line --partial "some kind of input"


}

@test "enroot mock creates file named as container and lists it" {

    enroot create --name thiscontainer imagename-ignored.sqsh
    enroot create --name thatcontainer imagename-ignored.sqsh

    run enroot list

    assert_output --partial thiscontainer
    assert_output --partial thatcontainer

}

@test "enroot remove removes containers " {

    enroot create --name thiscontainer imagename-ignored.sqsh
    enroot create --name thatcontainer imagename-ignored.sqsh
    enroot remove thiscontainer < <(echo yes)
    run enroot list
    refute_output --partial thiscontainer

}

@test "enroot start runs the script after -- and after container name" {

    cat <<EOF > ./script.sh
echo "something"
EOF
    chmod +x ./script.sh

    run enroot start -- container-name ./script.sh
    assert_output "something"

}

@test "enroot create needs name and image filename" {

    run enroot create --name thiscontainer

    assert_failure
    assert_output --partial "Image name missing!"




}
