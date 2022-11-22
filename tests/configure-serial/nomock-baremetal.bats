#!/usr/bin/env bash

function _on_horeka() {
   hostname | grep -q -E "hkn[0-9]{4}.localdomain"
}

function setup(){

    _on_horeka || skip

    load '../test_helper/bats-support/load' # for run
    load '../test_helper/bats-assert/load' # for assert_output and refute_output
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME" )/../.." > /dev/null 2>&1 && pwd)"

    # To make scripts in /src available for sourcing
    # and loading, and also make the sbatch mock available.
    export SRC="$PROJECT_ROOT"/src

    TEST_PLAYGROUND="$PWD/$(mktemp -d configure-testXXXXXXX)"
    export TEST_PLAYGROUND
    export STARTDIR="${TEST_PLAYGROUND}"/start
    export CUSTOM_ENV_CE_DEBUG=1
    mkdir -p "$STARTDIR"
    cd "$STARTDIR" || exit

    cat << EOF > get_jobid.py
import sys, json
dump = json.load(sys.stdin)
print(dump["job_env"]["CE_SLURM_JOB_ID"])
EOF


    echo "Test setup phase completed."

    # shellcheck disable=SC2030
    CUSTOM_ENV_CI_BUILDS_DIR="$TEST_PLAYGROUND"
    export CUSTOM_ENV_CI_BUILDS_DIR
    mkdir -p "$CUSTOM_ENV_CI_BUILDS_DIR" # This should not be needed

    ENVFILE="$CUSTOM_ENV_CI_BUILDS_DIR"/.env

}

function teardown() {
    echo scancel "$JOB_ID"
    scancel "$JOB_ID"
    echo rm -r "$TEST_PLAYGROUND"
    rm -r "$TEST_PLAYGROUND"
}

function wait_until_file_exists() {
    local FILE="$1"
    local MAXDELAY="$2"
    local T0="$SECONDS"
    while [[ ! -f "$FILE" && "$SECONDS" -lt $((T0+MAXDELAY)) ]]
    do
        sleep 1
    done

}


@test "configure launches allocation manager in slurm job - no container" {

    ############################################
    # STARTING ALLOCATION MANAGER IN SLURM JOB #
    ############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 1 -n 1"
    JOB_ID=$("$SRC"/configure-slurm-oci.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
	echo "squeue output:"
        squeue
        sleep 3
    done

    scontrol wait_job "$JOB_ID"

    wait_until_file_exists "$CUSTOM_ENV_CI_BUILDS_DIR"/.env 30

    assert [ -f "$CUSTOM_ENV_CI_BUILDS_DIR"/.env ]

}


@test "configure launches allocation manager in slurm job - no container - submission" {


    ############################################
    # STARTING ALLOCATION MANAGER IN SLURM JOB #
    ############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 1 -n 1"
    JOB_ID=$("$SRC"/configure-slurm-oci.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
	echo "squeue output:"
        squeue
        sleep 3
    done

    scontrol wait_job "$JOB_ID"

    wait_until_file_exists "$ENVFILE" 30

    ####################################
    # SUBMITTING TO ALLOCATION MANAGER #
    ####################################

    # shellcheck disable=SC1090
    source "$ENVFILE"
    # shellcheck disable=SC1091
    source "$SRC"/allocation_manager.sh

    cat << EOF > job.sh
#!/usr/bin/env bash
echo "Hello"

EOF
    chmod +x job.sh


    submit_to_allocation_manager job.sh


    wait_until_file_exists "${ALLOCATION_MANAGER_WORKSPACE}"/OUTPUT/job.sh.out \
        $((ALLOCATION_MANAGER_CYCLETIME*2))

    assert [ -f "${ALLOCATION_MANAGER_WORKSPACE}"/OUTPUT/job.sh.out ]
    run cat "${ALLOCATION_MANAGER_WORKSPACE}"/OUTPUT/job.sh.out
    # Making sure this has run in a container
    assert_output 'Hello'



}

@test "allocation manager is sent SIGUSR1 before end of job and trap is activated" {


    ############################################
    # STARTING ALLOCATION MANAGER IN SLURM JOB #
    ############################################

    # shellcheck disable=SC2030,SC2031
    export CUSTOM_ENV_COMMAND_OPTIONS_SBATCH="--partition=dev_cpuonly -t 2 -n 1"
    JOB_ID=$("$SRC"/configure-slurm-oci.sh | python3 get_jobid.py)

    # scontrol is slow, so it might query the job information
    # before it is actually available
    # and the test may fail
    while ! scontrol wait_job "$JOB_ID"
    do
	echo "squeue output:"
        squeue
        sleep 3
    done

    scontrol wait_job "$JOB_ID"

    wait_until_file_exists "$ENVFILE" 30
    source "$ENVFILE"

    cp $ALLOCATION_MANAGER_LOGFILE ~/allocmanlog.txt
    run sbatch -p dev_cpuonly -n 1 -t 1 \
        --dependency=afterany:"$JOB_ID" \
       	--wait \
	--wrap "grep -q 'Stopping allocation manager...' $ALLOCATION_MANAGER_LOGFILE"

    assert_success

}
