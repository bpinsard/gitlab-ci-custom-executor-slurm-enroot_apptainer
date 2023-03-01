#!/usr/bin/env bash

function setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load'
    load '../test-utils'
    _on_horeka || skip
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    export SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/configure-test-$BATS_TEST_NAME"
    echo "# Creating test playground in $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    # export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    cat << EOF > get_jobid.py
import sys, json
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_SLURM_JOB_ID"])
EOF


    echo "Test setup phase completed."

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_CI_WS
    mkdir -p "$CUSTOM_ENV_CI_WS" # This should not be needed

    CEQ_ENV="$CUSTOM_ENV_CI_WS/cews_$CUSTOM_ENV_CI_JOB_ID"/.env

}

function teardown() {
    if _on_horeka
    then
      echo scancel "$JOB_ID"
      scancel "$JOB_ID"
      while { squeue --format %i | grep -q "$JOB_ID"; }
      do
          echo "Waiting for job $JOB_ID to terminate..."
          sleep 5
      done
      echo rm -r "$TEST_PLAYGROUND"
      rm -r "$TEST_PLAYGROUND"
    fi
}



@test "configure launches custom executor queue in slurm job - no container" {

    ############################################
    # STARTING CUSTOM EXECUTOR QUEUE IN SLURM JOB #
    ############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 1 -n 1"
    JOB_ID=$("$SRC"/configure-slurm.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    scontrol_pre_wait_job_with_deadline "$JOB_ID" 600

    wait_until_file_exists "$CEQ_ENV" 30

    assert_file_exists "$CEQ_ENV"

}


@test "configure launches custom executor queue in slurm job - no container - submission" {


    ###############################################
    # STARTING CUSTOM EXECUTOR QUEUE IN SLURM JOB #
    ###############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 3 -n 1"
    JOB_ID=$("$SRC"/configure-slurm.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    scontrol_pre_wait_job_with_deadline "$JOB_ID" 600

    wait_until_file_exists "$CEQ_ENV" 30

    #######################################
    # SUBMITTING TO CUSTOM EXECUTOR QUEUE #
    #######################################

    # shellcheck disable=SC1090
    source "$CEQ_ENV"
    # shellcheck disable=SC1091
    source "$SRC"/custom_executor_queue.sh

    cat << EOF > job.sh
#!/usr/bin/env bash
echo "Hello"

EOF
    chmod +x job.sh


    submit_to_custom_executor_queue job.sh


    # DEBUG: This check is flaky.
    #        Adding 10 seconds just in case there is a delay
    #        of unknown reason.
    #        I honestly do not understand the reason why this
    #        additional delay is sometimes necessary.
    run wait_until_file_exists "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"/OUTPUT/job.sh.out \
        $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME*2))


    if [ "$status" -ne 0 ]
    then
      echo "The output of the job was not created in time."
      echo "Saving the content of $TEST_PLAYGROUND into $HOME/$BATS_TEST_NAME."
      cp -r "$TEST_PLAYGROUND" "$HOME/$BATS_TEST_NAME"
    fi


    assert_success

    echo "Logfile so far:"
    cat "$CUSTOM_EXECUTOR_QUEUE_LOGFILE" # For debugging
    echo "end of logfile"
    assert_file_exists "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/OUTPUT/job.sh.out"
    assert_file_contains "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/OUTPUT/job.sh.out" 'Hello'



}

@test "custom executor queue is sent SIGUSR1 before end of job and trap is activated" {


    ###############################################
    # STARTING CUSTOM EXECUTOR QUEUE IN SLURM JOB #
    ###############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 2 -n 1"
    JOB_ID=$("$SRC"/configure-slurm.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    scontrol_pre_wait_job_with_deadline "$JOB_ID" 600

    wait_until_file_exists "$CEQ_ENV" 30


    # shellcheck disable=SC1090
    source "$CEQ_ENV"

    run sbatch -p dev_cpuonly -n 1 -t 1 \
        --dependency=afterany:"$JOB_ID" \
       	--wait \
	--wrap "grep -q 'Stopping custom executor queue...' $CUSTOM_EXECUTOR_QUEUE_LOGFILE"

    assert_success

}
