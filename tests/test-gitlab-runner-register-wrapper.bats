#!/usr/bin/env bash


function get_slurm_default_partition() {
    set -o pipefail
    { scontrol show partition | grep -e "dev_\(single\|cpuonly\)" | cut -d= -f2; } || echo dev_cpuonly
    set +o pipefail
}

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
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    export MOCKLOGDIR="$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    URL_DEFAULT="https://gitlab.kit.edu/"
    ALLOWED_GITLAB_USERS_FILE="$TEST_PLAYGROUND/allowed_gitlab_users"

    GITLAB_RUNNER_MOCK_VERSION="$(
                 "$UTILS"/gitlab-runner-register-wrapper.sh --show-validated-runner-version-only
).1"
    export GITLAB_RUNNER_MOCK_VERSION

    MOCK_INPUTS=(url
                 token
                 name
                 cerepo # custom executor repository
                 enroot
                 cache_dir
                 ci_ws
                 default-partition
                 yes # use slurm
                 "$ALLOWED_GITLAB_USERS_FILE"
                 "Alice,Bob,Charles"
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

@test "accepts --container-backend and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "enroot" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backend 'enroot' \

        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-config-args.*enroot'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-args.*enroot'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-run-args.*enroot'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-cleanup-args.*enroot'

}

@test "accepts 'none' as --container-backend and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "enroot" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backend 'none' \

        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-config-args.*none'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-args.*none'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-run-args.*none'
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-cleanup-args.*none'


}

@test "acccepts --use-slurm as an argument" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --use-slurm yes

}

@test "useslurm used as argument for config when useslurm=yes" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-config-args.*useslurm'

}

@test "noslurm used as argument for config when useslurm=no" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "yes" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --use-slurm no
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-config-args.*noslurm'

}





@test "accepts --cache-dir-base and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "cache_dir" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --cache-dir-base "$TEST_PLAYGROUND/this/other/cache/dir" \

        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log "\-\-cache-dir=$TEST_PLAYGROUND/this/other/cache/dir"

}

@test "accepts --ci-ws and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "ci_ws" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --ci-ws "$TEST_PLAYGROUND/this/other/directory" \

        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log "\-\-env CI_WS=$TEST_PLAYGROUND/this/other/directory"

}

@test "accepts --default-partition and passes it to gitlab-runner register" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "default-partition" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --default-partition 'a-default-partition' \

        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log \
            '\-\-env DEFAULT_PARTITION=a-default-partition'

}

@test "prepare.sh is used as prepare-script" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-exec=.*/prepare.sh'

}

@test "useslurm used as argument for prepare" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "enroot" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backend 'none' \

        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-args.*useslurm'

}

@test "noslurm used as argument for prepare when useslurm=no" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "yes" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --use-slurm no
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-prepare-args.*noslurm'

}

@test "useslurm used as argument for run" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "enroot" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backend 'none' \

        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-run-args.*useslurm'

}

@test "noslurm used as argument for run when useslurm=no" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "yes" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --use-slurm no
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-run-args.*noslurm'

}


@test "useslurm used as argument for cleanup" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "enroot" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --container-backend 'none' \

        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-cleanup-args.*useslurm'

}

@test "noslurm used as argument for cleanup when useslurm=no" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "yes" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --use-slurm no
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log '\-\-custom-cleanup-args.*noslurm'

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

    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log "\-\-custom-config-exec=$PROJECT_ROOT/src/configure.sh"

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

@test "default value for DEFAULT_PARTITION is used if left blank" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "default-partition" ]]
        then
        echo "$mock_datum"
        else
            echo
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh


    SLURM_PARTITION_DEFAULT="$(get_slurm_default_partition)"
    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log \
        "\-\-env DEFAULT_PARTITION=$SLURM_PARTITION_DEFAULT"

}
@test "systemctl --user restart gitlab-runner.service is NOT called" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh


    assert_not_exists "$MOCKLOGDIR"/systemctl.log

}


@test "default value is displayed correctly for url:" {

    # shellcheck disable=SC2329
    function _helper(){
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

    # shellcheck disable=SC2329
    function _helper(){
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

@test "help contains default values (with <container-backend>)" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help

    assert_output --partial "$URL_DEFAULT"
    assert_output --partial "$PROJECT_ROOT"
    assert_output --partial "$HOME/gitlab-runner/cache/<container-backend>"
    assert_output --partial "$HOME/gitlab-runner"

}

@test "cache-dir passed to gitlab-runner register has <container-backend> at the end" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "cache_dir" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --cache-dir-base "$TEST_PLAYGROUND/this/other/cache/dir" \

        # the proper gitlab-runner option is still --cache-dir
        assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log \
            "\-\-cache-dir=$TEST_PLAYGROUND/this/other/cache/dir/enroot"
}

@test "cache-dir is created if it does not exist" {

    CACHE_DIR="$TEST_PLAYGROUND/cache_dir"
    assert_dir_not_exists "$CACHE_DIR"
    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "cache_dir" ]]
        then
        echo "$mock_datum"
        fi

    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --cache-dir-base "$CACHE_DIR" \

        assert_dir_exists "$CACHE_DIR"

}

@test "ci-ws is created if it does not exist" {

    CI_WS="$TEST_PLAYGROUND/ci_ws"
    assert_dir_not_exists "$CI_WS"
    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "ci_ws" ]]
        then
        echo "$mock_datum"
        fi

    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --ci-ws "$CI_WS" \

        assert_dir_exists "$CI_WS"

}
@test "--use-slurm mentioned in the help" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help

    assert_output --partial "--use-slurm"


}

@test "if --use-slurm no is used, do not add the default partition ENV" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "yes" ]]
        then
        echo "$mock_datum"
        fi

    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --use-slurm no \


        assert_file_not_contains "$MOCKLOGDIR"/gitlab-runner.log \
            "\-\-env DEFAULT_PARTITION"

}

@test "allowed gitlab users file created" {
    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "$ALLOWED_GITLAB_USERS_FILE" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --allowed-gitlab-users-file-path "$ALLOWED_GITLAB_USERS_FILE"

    [ -f "$ALLOWED_GITLAB_USERS_FILE" ]

}

@test "allowed gitlab users file path mentioned in the help" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help
    assert_output --partial "--allowed-gitlab-users-file-path"

}

@test "allowed gitlab users added to the file" {
    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        if [[ "$mock_datum" != "Alice,Bob,CharlesMock" ]]
        then
        echo "$mock_datum"
        fi
    done | "$UTILS"/gitlab-runner-register-wrapper.sh \
        --allowed-gitlab-users Alice,Bob,Charlie

    assert_file_contains "$ALLOWED_GITLAB_USERS_FILE" Alice
    assert_file_contains "$ALLOWED_GITLAB_USERS_FILE" Bob
    assert_file_contains "$ALLOWED_GITLAB_USERS_FILE" Charlie

}

@test "allowed gitlab users mentioned in the help" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help
    assert_output --partial "--allowed-gitlab-users "

}


@test "allowed gitlab users file passed to configure as argument" {

    for mock_datum in "${MOCK_INPUTS[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh


    assert_file_contains "$MOCKLOGDIR"/gitlab-runner.log \
        "\-\-custom-config-args=$ALLOWED_GITLAB_USERS_FILE"


}

@test "--disable-gitlab-user-check disables gitlab user check" {

    MOCK_INPUTS_TMP=(url
                     token
                     name
                     cerepo # custom executor repository
                     enroot
                     cache_dir
                     ci_ws
                     default-partition
                     yes # use slurm
                    )


    for mock_datum in "${MOCK_INPUTS_TMP[@]}"
    do
        echo "$mock_datum"
    done | "$UTILS"/gitlab-runner-register-wrapper.sh --disable-gitlab-user-check

    assert_file_not_contains "$MOCKLOGDIR"/gitlab-runner.log \
        "\-\-custom-config-args=$ALLOWED_GITLAB_USERS_FILE"



}

@test "--disable-gitlab-user-check mentioned in help" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help
    assert_output --partial "--disable-gitlab-user-check"
}

@test "--disable-gitlab-user-check and other options are not compatible" {

    MOCK_INPUTS_TMP=(url
                     token
                     name
                     cerepo # custom executor repository
                     enroot
                     cache_dir
                     ci_ws
                     default-partition
                     yes # use slurm
                    )


    # shellcheck disable=SC2329
    function _helper() {
        # shellcheck disable=SC2317
        for mock_datum in "${MOCK_INPUTS_TMP[@]}"
        do
            echo "$mock_datum"
        done | "$UTILS"/gitlab-runner-register-wrapper.sh \
            --disable-gitlab-user-check \
            --allowed-gitlab-users-file-path somewhere

    }

    run _helper

    assert_failure
    assert_output --partial "--disable-gitlab-user-check and --allowed-gitlab-users-file-path are incompatible options"

    _helper2() {
        for mock_datum in "${MOCK_INPUTS_TMP[@]}"
        do
            echo "$mock_datum"
        done | "$UTILS"/gitlab-runner-register-wrapper.sh \
            --disable-gitlab-user-check \
            --allowed-gitlab-users someone,someoneelse

    }

    run _helper2

    assert_failure
    assert_output --partial "--disable-gitlab-user-check and --allowed-gitlab-users are incompatible options"

}

@test "leaving empty allowed gitlab users filename disables the check on allowed users" {
    MOCK_INPUTS_TMP=(url
                     token
                     name
                     cerepo # custom executor repository
                     enroot
                     cache_dir
                     ci_ws
                     default-partition
                     yes # use slurm
                     ""
                    )

    # shellcheck disable=SC2329
    _helper() {
        for mock_datum in "${MOCK_INPUTS_TMP[@]}"
        do
            echo "$mock_datum"
        done | "$UTILS"/gitlab-runner-register-wrapper.sh
    }

    run _helper
    assert_success
    assert_exists "$MOCKLOGDIR"/gitlab-runner.log
    assert_equal "$(grep -o custom-config-args "$MOCKLOGDIR"/gitlab-runner.log | wc -l)" 2
    assert_output --partial "No check will be performed on gitlab users."

}

@test "gitlab runner version (major/minor) is checked and error is thrown if it does not match" {
    MOCK_INPUTS_TMP=(url
                     token
                     name
                     cerepo # custom executor repository
                     enroot
                     cache_dir
                     ci_ws
                     default-partition
                     yes # use slurm
                     ""
                    )

    # shellcheck disable=SC2329
    _helper() {
        for mock_datum in "${MOCK_INPUTS_TMP[@]}"
        do
            echo "$mock_datum"
        done | "$UTILS"/gitlab-runner-register-wrapper.sh
    }

    export GITLAB_RUNNER_MOCK_VERSION=17.9.25
    run _helper
    assert_failure
    assert_output --partial "This wrapper has not been manually tested with this gitlab runner version"
    assert_output --partial "Please contact the maintainers."

}

@test "--runner-version-check-only mentioned in help" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help
    assert_output --partial "--runner-version-check-only"
}

@test "--show-validated-runner-version-only mentioned in help" {

    run "$UTILS"/gitlab-runner-register-wrapper.sh --help
    assert_output --partial "--show-validated-runner-version-only"
}

@test "when --runner-version-check-only is used, no other action is performed by the runner" {


    "$UTILS"/gitlab-runner-register-wrapper.sh --runner-version-check-only


}
