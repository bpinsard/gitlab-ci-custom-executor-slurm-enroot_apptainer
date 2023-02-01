#!/usr/bin/env bash


function setup() {
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    load './test_helper/bats-file/load'
    load './test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    load_mocks
    UTILS="$PROJECT_ROOT/utils"

    TEST_PLAYGROUND="$PWD/gitlab-runner-wrapper-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    URL_DEFAULT="https://scs-gitlab.scc.kit.edu/"

    MOCK_INPUTS=(url
                 token
                 name
                 tags
                 cerepo # custom executor repository
                 enroot
                 builds_dir
                 cache_dir
                )
    }

function teardown() {
    rm -r "$TEST_PLAYGROUND"
}

@test "mock called" {


    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh

    assert_exists "$MOCKLOGDIR"/gitlab-runner.log

}

@test "accepts --url" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "url" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --url 'this.url.com'

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial '--url=this.url.com'

}

@test "accepts --registration-token and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "token" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --registration-token 'ASDASDASDASD'

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial '--registration-token=ASDASDASDASD'

}

@test "accepts --name and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "name" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --name 'a fake name' \

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial '--name="a fake name"'

}

@test "accepts --tags and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "tags" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --tags 'tags-like-this'

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial '--tag-list=tags-like-this'

}


@test "accepts --ce-repo and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "cerepo" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --ce-repo '/this/path' \

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --regexp 'config-exec.*/this/path'
    assert_output --regexp 'prepare-exec.*/this/path'
    assert_output --regexp 'run-exec.*/this/path'
    assert_output --regexp 'cleanup-exec.*/this/path'

}

@test "accepts --container-backend and passes it to gitlab-runner register" {

 for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "container_backend" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backend 'enroot' \

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --regexp '--custom-prepare-args.*enroot'
    assert_output --regexp '--custom-run-args.*enroot'
    assert_output --regexp '--custom-cleanup-args.*enroot'

}

@test "accepts --builds-dir and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "builds_dir" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --builds-dir '/this/other/builds/dir' \

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --regexp 'builds-dir=/this/other/builds/dir'

}

@test "accepts --cache-dir and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "cache_dir" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --cache-dir '/this/other/cache/dir' \

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --regexp 'cache-dir=/this/other/cache/dir'

}


@test "complains if bad option is passed" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --wrong-option
    assert_failure
    assert_output --partial "unrecognized option"

}

@test "complains if options have no argument" {

    for option in --url \
        --registration-token \
        --name \
        --description \
        --tags \
        --tag-list \
        --ce-repo
    do
        run "$UTILS"/gitlab-runner-register-wrapper.sh "$option"
        assert_failure
        assert_output --partial "option '$option' requires an argument"
    done

}

@test "default value for the url is used if left blank" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "url" ]]
        then
            echo "$mock_datum"
        else
            echo
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial "--url=$URL_DEFAULT"

}

@test "default value for the custom executor repo is used if left blank" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "cerepo" ]]
        then
            echo "$mock_datum"
        else
            echo
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial "--custom-config-exec=$PROJECT_ROOT/src/configure-slurm.sh"

}

@test "default value for builds_dir is used if left blank" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "builds_dir" ]]
        then
            echo "$mock_datum"
        else
            echo
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial "--builds-dir=$HOME/gitlab-runner/builds"

}

@test "default value for cache_dir is used if left blank" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "cache_dir" ]]
        then
            echo "$mock_datum"
        else
            echo
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial "--cache-dir=$HOME/gitlab-runner/cache"

}

@test "systemctl --user restart gitlab-runner.service is called" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh


    run cat "$MOCKLOGDIR"/systemctl.log
    assert_output --partial "--user restart gitlab-runner.service"

}


@test "default value is displayed correctly for url:" {

    _helper(){
        # shellcheck disable=SC2317
        for mock_datum in "${MOCK_INPUTS[@]}"
        do
            # shellcheck disable=SC2317
            echo "$mock_datum"
        done | "$UTILS"/gitlab-runner-register-wrapper.sh
    }
    run _helper

    assert_line "Gitlab instance url ($URL_DEFAULT):"

}

@test "default value is displayed correctly for the custom executor repo:" {

    _helper(){
        # shellcheck disable=SC2317
        for mock_datum in "${MOCK_INPUTS[@]}"
        do
            # shellcheck disable=SC2317
            echo "$mock_datum"
        done | "$UTILS"/gitlab-runner-register-wrapper.sh
    }

    run _helper

    assert_line "Location of the custom executor repository ($PROJECT_ROOT):"

}

@test "--help prints help" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help

    assert_output --partial "This script"
    assert_output --partial "--help"

}

@test "help contains default values" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help

    assert_output --partial "(default: $URL_DEFAULT)"
    assert_output --partial "(default: $PROJECT_ROOT)"
    assert_output --partial "(default: $HOME/gitlab-runner/builds)"
    assert_output --partial "(default: $HOME/gitlab-runner/cache)"

}
