#!/usr/bin/env bash
#SBATCH --output /home/hk-project-scs/%u/cetest%J.out  
#SBATCH --error /home/hk-project-scs/%u/cetest%J.err  
#SBATCH --job-name GitLabCustomExec


if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
set -o nounset
set -o errexit
set -o pipefail

ALLOCATION_MANAGER_WORKSPACE=$1
SRC=$2

source "$SRC"/allocation_manager.sh

echo -n "Starting allocation manager... " >&2
start_allocation_manager "$ALLOCATION_MANAGER_WORKSPACE"
echo -n "done. Waiting." >&2

source "$ALLOCATION_MANAGER_WORKSPACE"/.env

trap "kill -s SIGUSR1 $ALLOCATION_MANAGER_JOBID; wait; exit" SIGUSR1

while true
do 
	sleep  1
done
