#!/usr/bin/env bash

setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load' # for assert_output and refute_output
    load '../test-utils'
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    PATH="$PROJECT_ROOT/tests/mocks/bin:$PROJECT_ROOT/src/slurm-utils:$PATH"
    TEST_PLAYGROUND=$PWD/$(mktemp -d sbatch-mock-testXXXXXXX)
    echo "Created test playground at $TEST_PLAYGROUND" >&3
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

    rm -r "$TEST_PLAYGROUND"
}

@test "sbatch mock complains if no log location is given" {

    (
    # shellcheck disable=SC2030
    export MOCKLOGDIR=
    refute sbatch --something
    )

}

@test "sbatch mock records logs at a given location" {

    sbatch --something echo
    # shellcheck disable=SC2031
    assert_file_exists "$MOCKLOGDIR"/sbatch.log

}

@test "sbatch mock records arguments correctly" {

    sbatch --something --like --this echo
    # shellcheck disable=SC2031
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "--something --like --this"

}

@test "sbatch mock records SBATCH-related environment variables in log" {

    (
    export SBATCH_GPUS=volta:3
    sbatch --something --like --this echo
    )
    # shellcheck disable=SC2031
    run cat "$MOCKLOGDIR"/sbatch.log
    assert_output --partial "SBATCH_GPUS=volta:3"
}

@test "sbatch mock records ONLY SBATCH-related environment variables in the proper list" {

    (
    # Unfortunately this is not one of the sbatch input environment variables.
    export SLURM_NTASKS=5
    sbatch --something --like --this echo
    )
    # shellcheck disable=SC2031
    run cat "$MOCKLOGDIR"/sbatch.log
    refute_output --partial "SLURM_NTASKS=5"

}

function _on_horeka () {
    hostname | grep -q -E "hkn[0-9]{4}.localdomain"
}



@test "sbatch input environment variables read from docs are the expected ones" {

   _on_horeka || skip
   local MOCK="$PROJECT_ROOT"/tests/mocks
   local SRC="$PROJECT_ROOT"/src

   N=$(diff <("$SRC"/slurm-utils/_get-sbatch-input-env-list.sh | sort )  \
            <( "$MOCK"/bin/get-sbatch-input-env-list.sh | sort )  \
   | wc -l)
   assert_equal "$N" 0


}

@test "sbatch mock tries to execute the first non option argument" {
    # This is not how real sbatch works,
    # but we need to keep things simple here.

    cat <<EOF > job.sh
touch "\$1"
EOF
    chmod +x job.sh

    sbatch --some --options ./job.sh output.sh

    wait_until_file_exists output.sh 10
    # This is not robust
    # (failure of this does not necessarily mean
    # failure of the test)
    assert_file_exists output.sh


}

@test "sbatch mock echoes a number only" {
    # This should be true only if called with --parsable

    touch job.sh
    chmod +x job.sh

    run sbatch --parsable --some --options ./job.sh
    assert_output --regexp "[0-9]+"

}

@test "sbatch mock saves the output and error stream somewhere else, not in output" {
    # This is not how real sbatch works,
    # but we need to keep things simple here.

    cat <<EOF > job.sh
echo Hello
EOF
    chmod +x job.sh

    run sbatch --some --options ./job.sh output.sh
    refute_output --partial "Hello"


}

@test "sbatch mock saves the PID of the executable launched in the background in a file" {

    cat <<EOF > job.sh
echo Hello
EOF
    chmod +x job.sh

    sbatch --some --options ./job.sh output.sh

    assert_file_exists "$MOCKLOGDIR/pids.txt"

}
