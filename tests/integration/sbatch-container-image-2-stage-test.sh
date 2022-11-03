#!/bin/bash
JOBID=$(sbatch -p dev_cpuonly -n 1 -t 5 --wrap "sleep 300" --parsable)


sbatch --partition dev_cpuonly --dependency=after:$JOBID -n 1 -t 1 --wait --wrap "echo waiting" -o /dev/null

srun --jobid=$JOBID --overlap --container-image=alpine:latest --container-mounts=/scratch:/scratch,/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk -n 1 -t 1 grep PRETTY /etc/os-release

scancel $JOBID

srun --partition dev_cpuonly --container-image=alpine:latest --container-mounts=/scratch:/scratch,/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk -n 1 -t 1 grep PRETTY /etc/os-release

srun --partition dev_cpuonly --container-image=alpine:latest --container-mounts=/scratch:/scratch,/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk -n 1 -t 1 "grep PRETTY /etc/os-release"
