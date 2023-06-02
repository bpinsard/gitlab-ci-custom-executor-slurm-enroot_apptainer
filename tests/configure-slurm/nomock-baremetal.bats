#!/usr/bin/env bash

function has_slurm(){
    which sbatch &> /dev/null

}

function setup(){
    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    load '../test_helper/bats-file/load'
    load '../test-utils'
    has_slurm || skip
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    export SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/configure-test-$BATS_TEST_NAME"
    
    echo "# Creating test playground in $TEST_PLAYGROUND" >&3
    mkdir "$TEST_PLAYGROUND"
    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    # export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    cat << EOF > get_workspace.py
import sys, json
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_QUEUE_WORKSPACE"])
EOF


    echo "Test setup phase completed."

    # shellcheck disable=SC2030
    export CUSTOM_ENV_CI_WS="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_JOB_ID=54321
    export CUSTOM_ENV_CI_WS
    mkdir -p "$CUSTOM_ENV_CI_WS" # This should not be needed

    if [ -z "$CUSTOM_ENV_DEFAULT_PARTITION" ]
    then
      # If we are in a testing environment,
      # it might be that CUSTOM_ENV_DEFAULT_PARTITION is not defined
      # while DEFAULT_PARTITION is defined instead.
      export CUSTOM_ENV_DEFAULT_PARTITION="$DEFAULT_PARTITION"
    fi
    if [ -z "$CUSTOM_ENV_DEFAULT_PARTITION" ]
    then
      echo "Error:CUSTOM_ENV_DEFAULT_PARTITION not defined"
      exit 1
    fi


    CEQ_ENV="$CUSTOM_ENV_CI_WS/cews_0"/.env

}

function teardown() {
    if has_slurm
    then
      echo scancel "$JOB_ID"
      scancel "$JOB_ID"
      while { squeue --format %i | grep -q "$JOB_ID"; }
      do
          echo "Waiting for job $JOB_ID to terminate..."
          sleep 5
      done
      echo try_to_remove_dir "$TEST_PLAYGROUND"
      try_to_remove_dir "$TEST_PLAYGROUND"
    fi
}



@test "configure launches custom executor queue in slurm job - no container" {

    ############################################
    # STARTING CUSTOM EXECUTOR QUEUE IN SLURM JOB #
    ############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 1 -n 1"
    WORKSPACE=$("$SRC"/configure-slurm.sh | python3 get_workspace.py)
    # shellcheck source=./src/include.sh
    source "$SRC/include.sh"
    JOB_ID="$(get_slurm_jobid "$WORKSPACE")"


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
    WORKSPACE=$("$SRC"/configure-slurm.sh | python3 get_workspace.py)
    # shellcheck source=./src/include.sh
    source "$SRC/include.sh"
    JOB_ID="$(get_slurm_jobid "$WORKSPACE")"


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

    # Choosing a complicated name here for better
    JOBNAME=job-config-launches-ce-queue-slurm-job.sh
    cat << EOF > "$JOBNAME"
#!/usr/bin/env bash
echo "Hello"

EOF
    chmod +x "$JOBNAME"


    TODONAME="$(submit_to_custom_executor_queue "$JOBNAME" JOB-"$CUSTOM_ENV_CI_JOB_ID")"
    BNAME="$(basename "$TODONAME")"

    # DEBUG: This check is flaky.
    #        Adding 10 seconds just in case there is a delay
    #        of unknown reason.
    #        I honestly do not understand the reason why this
    #        additional delay is sometimes necessary.
    run wait_until_file_exists "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/OUTPUT/$BNAME.out" \
        $((CUSTOM_EXECUTOR_QUEUE_CYCLETIME*2+10))


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
    assert_file_exists "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/OUTPUT/$BNAME.out"
    echo "Output of job:"
    echo "====================="
    cat "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/OUTPUT/$BNAME.out"
    echo "====================="
    echo "Content of workspace:"
    echo "====================="
    find "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}"
    echo "====================="
    assert_file_contains "${CUSTOM_EXECUTOR_QUEUE_WORKSPACE}/OUTPUT/$BNAME.out" 'Hello'



}

@test "custom executor queue is sent SIGUSR1 before end of job and trap is activated" {


    ###############################################
    # STARTING CUSTOM EXECUTOR QUEUE IN SLURM JOB #
    ###############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 2 -n 1"
    WORKSPACE=$("$SRC"/configure-slurm.sh | python3 get_workspace.py)
    # shellcheck source=./src/include.sh
    source "$SRC/include.sh"
    JOB_ID="$(get_slurm_jobid "$WORKSPACE")"

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
