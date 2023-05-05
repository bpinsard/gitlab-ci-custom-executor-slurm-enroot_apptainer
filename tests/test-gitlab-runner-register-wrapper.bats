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
                 ci_ws
                )
    }

function teardown() {
    try_to_remove_dir "$TEST_PLAYGROUND"
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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-url=this.url.com'

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-registration-token=ASDASDASDASD'

}

@test "accepts --name and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "name" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --name 'a_fake_name' \

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-name=a_fake_name'

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-tag-list=tags-like-this'

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log 'config-exec.*/this/path'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log 'prepare-exec.*/this/path'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log 'run-exec.*/this/path'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log 'cleanup-exec.*/this/path'

}

@test "accepts --container-backends and passes it to gitlab-runner register" {

 for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "container_backends" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backends 'enroot' \

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-args.*enroot'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-run-args.*enroot'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-cleanup-args.*enroot'

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-builds-dir=/this/other/builds/dir'

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-cache-dir=/this/other/cache/dir'

}


@test "accepts --ci-ws and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "ci_ws" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --ci-ws '/this/other/directory' \

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-env CI_WS=/this/other/directory'

}
@test "prepare.sh is used as prepare-script" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-exec=.*/prepare.sh'

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log "\-\-url=$URL_DEFAULT"

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log "\-\-custom-config-exec=$PROJECT_ROOT/src/configure-slurm.sh"

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log "\-\-builds-dir=$HOME/gitlab-runner/builds"

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log "\-\-cache-dir=$HOME/gitlab-runner/cache"

}

@test "default value for CI WS is used if left blank" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "ci_ws" ]]
        then
            echo "$mock_datum"
        else
            echo
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log "\-\-env CI_WS=$HOME/gitlab-runner"

}
@test "systemctl --user restart gitlab-runner.service is NOT called" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh


    assert_not_exists "$MOCKLOGDIR"/systemctl.log

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

    assert_output --partial "$URL_DEFAULT"
    assert_output --partial "$PROJECT_ROOT"
    assert_output --partial "$HOME/gitlab-runner/builds"
    assert_output --partial "$HOME/gitlab-runner/cache"

}

@test "accepts multiple container backends" {

 for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "enroot" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backends all

    cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-args.*enroot'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-run-args.*enroot'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-cleanup-args.*enroot'

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-args.*singularity'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-run-args.*singularity'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-cleanup-args.*singularity'

}

@test "when using all, one runner is registered with tag enroot, another with tag singularity and another without them" {

 for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "enroot" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backends all

    _check_number_calls(){
     grep -c "ARGS:" "$MOCKLOGDIR"/gitlab-runner.log
    }
    run _check_number_calls
    assert_output 3

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\--tag-list=tags,enroot'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\--tag-list=tags,singularity'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\--tag-list=tags '

}


@test "during registration, the tags for the runner are printed out when using enroot backend" {

  function _helper(){
     # shellcheck disable=SC2317
     for mock_datum in "${MOCK_INPUTS[@]}"
     do
         # shellcheck disable=SC2317
         echo "$mock_datum"
     done | "$UTILS"/gitlab-runner-register-wrapper.sh
  }

  run _helper

  assert_line --regexp "Runner using enroot backend set with tags=\"tags\""

}

@test "during registration, the tags for the runner are printed out when using both backends" {

  function _helper(){
     for mock_datum in "${MOCK_INPUTS[@]}"
     do
        if [[ "$mock_datum" != "enroot" ]]
        then
        echo "$mock_datum"
        fi
     done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backends all
  }

  run _helper

  assert_line --regexp "Runner using enroot backend set with tags=\"tags,enroot\""
  assert_line --regexp "Runner using singularity backend set with tags=\"tags,singularity\""

}
