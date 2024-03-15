#!/usr/bin/env bash

function setup(){
    load './test_helper/bats-support/load' # for run
    load './test_helper/bats-assert/load' # for assert_output and refute_output
    load './test_helper/bats-file/load' # for assert_output and refute_output
    load './doc-test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/.." > /dev/null 2>&1 && pwd)"
    SRC="$PROJECT_ROOT/src"
    TESTDIR="$PROJECT_ROOT/tests"
    README="$PROJECT_ROOT/README.md"
}

@test "README.md exists" {

    assert_exist "$README"

}

# Not nice, coupling documentation directly to code
# TODO: couple to test instead
@test "default slurm allocation is 600 seconds" {

    # Test the readme
    grep -qi "If the variable is not set, it is assumed" "$README"
    grep -qi "that the job takes 600 seconds." "$README"

    # Test the code
    # shellcheck disable=SC2016
    grep_ignoring_hash_comments -A 3 -n 'determine_slurm_workspace' "$SRC"/configure.sh | grep '"${CUSTOM_ENV_JOB_TIME_SEC:-600}"'

}

@test "slurm allocation not reused if REUSE_WORKSPACE=OFF " {
    grep_between "Slurm allocation settings" "##" '.*' "$README"


    # Test the readme
    grep_between "Slurm allocation settings" "##" -qi "allocation is not reused" "$README"
    # shellcheck disable=SC2016
    grep_between "Slurm allocation settings" "##" -qi 'if.*`REUSE_WORKSPACE`.*`OFF`' "$README"


    # Test the test code
    # shellcheck disable=SC2016
    grep_ignoring_hash_comments -q '"when envs match and time is enough but REUSE_WORKSPACE == OFF, allocation not reused"' "$TESTDIR"/configure-slurm/test.bats
}

@test "committer restriction mentioned and implemented" {

    SECTION_TITLE="Important: Allowed committers for an executor"
    grep "$SECTION_TITLE" "$README"

    grep_between "$SECTION_TITLE" '^##' -qi 'https://docs.gitlab.com/runner/security/' "$README"

    grep_ignoring_hash_comments -q "allowed committers are checked at the configure stage - failure" "$TESTDIR"/configure/tests.bats
    grep_ignoring_hash_comments -q "allowed committers are checked at the configure stage - success" "$TESTDIR"/configure/tests.bats
    grep_ignoring_hash_comments -q "allowed committers are checked at the configure stage - substring failure" "$TESTDIR"/configure/tests.bats

}

@test "CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE mentioned and implemented" {

    SECTION_TITLE="Important: Allowed committers for an executor"

    grep_between "$SECTION_TITLE" '^##' -q 'CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE' "$README"

    grep_ignoring_hash_comments -q "if CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE not defined, fail if GITLAB_USER_LOGIN!=USER" "$TESTDIR"/configure/tests.bats

    # shellcheck disable=SC2016
    grep_between "$SECTION_TITLE" '^##' -q 'If `CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE` is empty or not set' "$README"

}

@test "CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE managed by gitlab-runner-register-wrapper" {

    [ -x "$PROJECT_ROOT/utils/gitlab-runner-register-wrapper.sh" ]

    SECTION_TITLE="Important: Allowed committers for an executor"
    grep_between "$SECTION_TITLE" '^##' -q 'gitlab-runner-register-wrapper.sh' "$README"



    grep_ignoring_hash_comments \
        -q "CI_ALLOWED_COMMITTERS_FILE created" \
        "$TESTDIR"/test-gitlab-runner-register-wrapper.bats


}
