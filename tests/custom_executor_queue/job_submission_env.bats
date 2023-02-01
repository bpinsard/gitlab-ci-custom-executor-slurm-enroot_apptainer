#!/usr/bin/env bash

setup(){
    load 'common_setup'
    _common_setup
    source "$PROJECT_ROOT/src/custom_executor_queue.sh"

    TEST_PLAYGROUND="$PWD/ce-queue-job-sub-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"


    WORKDIR="${TEST_PLAYGROUND}"/cews
    STARTDIR="${TEST_PLAYGROUND}"/start

    mkdir -p "${STARTDIR}"
    cd "${STARTDIR}"


}

teardown(){
    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    stop_custom_executor_queue
    _common_teardown
}

@test "env vars exported at submission are available when job runs" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat << EOF > job.sh
    echo \$MY_VARIABLE

EOF
    chmod +x job.sh

    (

    export MY_VARIABLE="some-thing"
    run submit_to_custom_executor_queue_and_wait job.sh
    assert_output "some-thing"
    )


}

@test "env vars in the blacklist pattern at submission time are not available when job runs" {

    (start_custom_executor_queue "$WORKDIR" 3> /dev/null)

    # shellcheck disable=SC1091
    source "$WORKDIR"/.env
    cat << EOF > job.sh
    echo \$SLURM_SOMETHING

EOF
    chmod +x job.sh

    (

    export SLURM_SOMETHING="some-thing"
    run submit_to_custom_executor_queue_and_wait job.sh
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

    _helper() {
        # shellcheck disable=SC2317
        cat <<EOF | purge_variables
declare -r READONLY_VAR1=12345
declare -r READONLY_VAR2=09876
declare -r READONLY_VAR=this-should-be-visible
EOF
    }

    run _helper
    refute_output --partial "READONLY_VAR1"
    refute_output --partial "READONLY_VAR2"
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
declare -x DONTPURGETHIS=this-must-stay
EOF
    }

    run _helper
    refute_output --partial "SLURM"
    refute_output --partial "BATS"
    refute_output --partial "BASH"
    assert_line "declare -x DONTPURGETHIS=this-must-stay"

}
