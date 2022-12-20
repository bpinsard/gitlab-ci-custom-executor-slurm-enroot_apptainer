#!/usr/bin/env bash
# THIS SEEMS TO WORK NOW
echo Create the allocation and get the job ID
echo This job runs on the host, no container
JOBID=$(sbatch -p dev_cpuonly -n 1 -t 5 --wrap "sleep 300" --parsable)

echo "$JOBID" created

while ! scontrol wait_job "$JOBID"
do
	sleep 3
done

echo "Running a job step in a container inside the allocation at $JOBID"
srun --dependency=after:"$JOBID" \
     --jobid="$JOBID" --overlap \
     --container-image=alpine:latest \
     --container-mounts=/scratch:/scratch,/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk \
     -n 1 -t 1 grep PRETTY /etc/os-release

scancel "$JOBID"

