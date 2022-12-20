#!/usr/bin/env bash
#SBATCH -t 2
#SBATCH -n 1
#SBATCH -p dev_cpuonly
#SBATCH --output slurm-signal-test.out
#SBATCH --error slurm-signal-test.err

trap "exit 0" SIGUSR1

while true
do 
	sleep 1
done
# Trap is triggered with
# scancel --batch --signal=SIGUSR1 <jobid>
