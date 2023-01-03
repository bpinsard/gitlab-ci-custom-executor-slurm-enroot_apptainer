#!/usr/bin/env bash

function setup() {
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test-utils'

    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"
    export PROJECT_ROOT

    load_mocks

    TEST_PLAYGROUND="$PWD/read-job-env-test-$BATS_TEST_NAME"
    echo "Creating test playground at $TEST_PLAYGROUND"
    mkdir "$TEST_PLAYGROUND"

    STARTDIR="${TEST_PLAYGROUND}"/start
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit


    }


function teardown(){

    rm -r "$TEST_PLAYGROUND"


}

@test "read-job-env reads correctly the json output (by configure)" {

    cat <<EOF > json-output
{
  "driver": {
    "name": "ENROOT+Slurm driver",
    "version": "v0.0.1"
  },
"job_env": {
    "CE_SLURM_JOB_ID": "1234723",
    "CE_QUEUE_ENV_PATH" : "/some/path/.env"
  }
}

EOF

    run read-job-env.py < json-output

    assert_line 'export CE_SLURM_JOB_ID=1234723'
    assert_line 'export CE_QUEUE_ENV_PATH=/some/path/.env'

}
