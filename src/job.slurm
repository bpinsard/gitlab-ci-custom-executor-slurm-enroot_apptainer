#!/usr/bin/env bash
#SBATCH --output /home/hk-project-scs/%u/cetest%J.out  
#SBATCH --error /home/hk-project-scs/%u/cetest%J.err  
#SBATCH --job-name GitLabCustomExec


if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
set -o nounset
set -o errexit
set -o pipefail

CUSTOM_EXECUTOR_QUEUE_WORKSPACE=$1
SRC=$2

source "$SRC"/custom_executor_queue.sh

echo -n "Starting custom executor queue... " >&2
start_custom_executor_queue "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"
echo -n "done. Waiting." >&2

source "$CUSTOM_EXECUTOR_QUEUE_WORKSPACE"/.env

trap "kill -s SIGUSR1 $CUSTOM_EXECUTOR_QUEUE_JOBID; wait; exit" SIGUSR1

while true
do 
	sleep  1
done
