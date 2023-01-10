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
    }

function teardown() {
    rm -r "$TEST_PLAYGROUND"
}

@test "mock called" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
token
name
tags
cerepo
EOF

    "$UTILS"/gitlab-runner-register-wrapper.sh < gitlab-runner-mock-input.txt

    assert_exists "$MOCKLOGDIR"/gitlab-runner.log

}

@test "accepts --url" {

    cat <<EOF > gitlab-runner-mock-input.txt
token
name
tags
cerepo
EOF

    "$UTILS"/gitlab-runner-register-wrapper.sh \
         --url 'this.url.com' \
         < gitlab-runner-mock-input.txt
    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial '--url=this.url.com'

}

@test "accepts --registration-token and passes it to gitlab-runner register" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
name
tags
cerepo
EOF

    "$UTILS"/gitlab-runner-register-wrapper.sh \
        --registration-token 'ASDASDASDASD' \
        < gitlab-runner-mock-input.txt
    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial '--registration-token=ASDASDASDASD'

}

@test "accepts --name and passes it to gitlab-runner register" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
token
tags
cerepo
EOF

    "$UTILS"/gitlab-runner-register-wrapper.sh \
        --name 'a fake name' \
        < gitlab-runner-mock-input.txt
    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial '--name="a fake name"'

}

@test "accepts --tags and passes it to gitlab-runner register" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
token
name
cerepo
EOF

    "$UTILS"/gitlab-runner-register-wrapper.sh \
        --tags 'tags-like-this' \
        < gitlab-runner-mock-input.txt

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial '--tag-list=tags-like-this'

}


@test "accepts --ce-repo and passes it to gitlab-runner register" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
token
name
tags
EOF

    "$UTILS"/gitlab-runner-register-wrapper.sh \
        --ce-repo '/this/path' \
        < gitlab-runner-mock-input.txt
    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --regexp 'config-exec.*/this/path'
    assert_output --regexp 'prepare-exec.*/this/path'
    assert_output --regexp 'run-exec.*/this/path'
    assert_output --regexp 'cleanup-exec.*/this/path'

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

    cat <<EOF > gitlab-runner-mock-input.txt

token
name
tags
cerepo
EOF


    "$UTILS"/gitlab-runner-register-wrapper.sh < gitlab-runner-mock-input.txt


    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial "--url=$URL_DEFAULT"

}

@test "default value for the custom executor repo is used if left blank" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
token
name
tags

EOF


    "$UTILS"/gitlab-runner-register-wrapper.sh < gitlab-runner-mock-input.txt

    run cat "$MOCKLOGDIR"/gitlab-runner.log
    assert_output --partial "--custom-config-exec=$PROJECT_ROOT/src/configure-slurm.sh"

}

@test "systemctl --user restart gitlab-runner.service is called" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
token
name
tags
cerepo
EOF


    "$UTILS"/gitlab-runner-register-wrapper.sh < gitlab-runner-mock-input.txt

    run cat "$MOCKLOGDIR"/systemctl.log
    assert_output --partial "--user restart gitlab-runner.service"

}


@test "default value is displayed correctly for url:" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
token
name
tags
cerepo
EOF

    run "$UTILS"/gitlab-runner-register-wrapper.sh < gitlab-runner-mock-input.txt

    assert_line "Gitlab instance url ($URL_DEFAULT):"

}

@test "default value is displayed correctly for the custom executor repo:" {

    cat <<EOF > gitlab-runner-mock-input.txt
url
token
name
tags
cerepo
EOF

    _helper(){ "$UTILS"/gitlab-runner-register-wrapper.sh < gitlab-runner-mock-input.txt; }

    run _helper

    assert_line "Location of the custom executor repository ($PROJECT_ROOT):"

}
