#!/usr/bin/env bash
setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    PATH="$PROJECT_ROOT/src/slurm-utils:$PATH"
    load_mocks
    TEST_PLAYGROUND="$PWD/sbatch-mock-test-$BATS_TEST_NAME"
    echo "# Creating test playground at $TEST_PLAYGROUND" >&3
    create_dir_or_error_if_exists "$TEST_PLAYGROUND"
    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit
    echo "Created test playground at $TEST_PLAYGROUND"
    export MOCKLOGDIR=$TEST_PLAYGROUND

}

teardown(){
    if [ -f "$MOCKLOGDIR"/pids.txt  ]
    then
        awk '{print $1}' "$MOCKLOGDIR"/pids.txt | xargs kill
    fi

    try_to_remove_dir "$TEST_PLAYGROUND"
}


# bats test_tags=skipped-local
@test "sbatch input environment variables read from docs are the expected ones" {

   has_slurm || skip
   local MOCK="$PROJECT_ROOT"/tests/mocks
   local SRC="$PROJECT_ROOT"/src

   "$SRC"/slurm-utils/_get-sbatch-input-env-list.sh | sort > real
   "$MOCK"/bin/get-sbatch-input-env-list.sh | sort  > mock

   diff real mock | tee diff-real-mock

   N=$( wc -l < diff-real-mock)

   assert_equal "$N" 0

}
