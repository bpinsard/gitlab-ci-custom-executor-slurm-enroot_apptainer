#!/usr/bin/env bash

setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    TEST_PLAYGROUND="$PWD/ce-queue-job-sub-test-env-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"


    WORKDIR="${TEST_PLAYGROUND}"/cews
    STARTDIR="${TEST_PLAYGROUND}"/start

    mkdir -p "${STARTDIR}"
    cd "${STARTDIR}" || exit


}

teardown(){
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
    _common_teardown
}

@test "env vars not exported to job env when not using --with-env" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    echo "Environment:"
    echo "================================="
    cat "$WORKDIR"/.env
    echo "================================="

    cat << EOF > job.sh
    echo \$MY_VARIABLE

EOF
    chmod +x job.sh

    (
    # shellcheck disable=SC2030
    export MY_VARIABLE="some-thing"
    function _helper(){
        # shellcheck disable=SC2317
        submit_to_custom_executor_queue_and_wait job.sh JOB-54321 | grep -v "has ended,"
    }
    run _helper
    assert_success
    assert_output ""
    )


}


@test "env vars exported at submission are available when job runs when using --with-env" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    echo "Environment:"
    echo "================================="
    cat "$WORKDIR"/.env
    echo "================================="

    cat << EOF > job.sh
    echo \$MY_VARIABLE
    echo Something else
EOF
    chmod +x job.sh

    (
    # shellcheck disable=SC2031
    export MY_VARIABLE="some-thing"
    run submit_to_custom_executor_queue_and_wait job.sh JOB-54321 --with-env
    assert_output --partial "some-thing"
    )


}

@test "env vars in the blacklist pattern at submission time are not available when job runs" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    echo "Environment:"
    echo "================================="
    cat "$WORKDIR"/.env
    echo "================================="

    cat << EOF > job.sh
    echo \$SLURM_SOMETHING

EOF
    chmod +x job.sh

    (

    export SLURM_SOMETHING="some-thing"
    function _helper(){
        # shellcheck disable=SC2317
        submit_to_custom_executor_queue_and_wait job.sh JOB-54321 | grep -v "has ended,"
    }
    run _helper
    assert_success
    assert_output ""
    )

}

@test "purge variables removes readonly variables" {

    # This is not needed by the test but only by the teardown
    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

    # shellcheck disable=SC2034
    declare -r READONLY_VAR1=42
    # shellcheck disable=SC2034
    declare -r READONLY_VAR2=42

    # shellcheck disable=SC2034
    declare -ir VARNOVALUE

    _helper() {
        # shellcheck disable=SC2317
        cat <<EOF | purge_variables
declare -r READONLY_VAR1=12345
declare -r READONLY_VAR2=09876
declare -ir VARNOVALUE
declare -r READONLY_VAR=this-should-be-visible
EOF
    }

    run _helper
    refute_output --partial "READONLY_VAR1"
    refute_output --partial "READONLY_VAR2"
    refute_output --partial "BASHPID"
    assert_line "declare -r READONLY_VAR=this-should-be-visible"

}

@test "purge variables removes variables matching patterns in blacklist" {

    # This is not needed by the test but only by the teardown
    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)


    _helper() {
        # shellcheck disable=SC2317
        cat <<EOF | purge_variables
declare -x BATS_SOMETHING=something
declare -x FUNCNAME=funcs
declare -x GROUPS=somegroups
declare -x SLURM_SOMETHING=somethingelse
declare -x BASH_SOMETHING=yet-somethingelse
declare -ir BASHPID
declare -x DONTPURGETHIS=this-must-stay
EOF
    }

    run _helper
    refute_output --partial "SLURM"
    refute_output --partial "BATS"
    refute_output --partial "BASH"
    assert_line "declare -x DONTPURGETHIS=this-must-stay"

}
