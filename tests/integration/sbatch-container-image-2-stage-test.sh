#!/usr/bin/env bash
echo Create the allocation and get the job ID
echo This job runs on the host, no container
JOBID=$(sbatch -p dev_cpuonly -n 1 -t 5 --wrap "sleep 300" --parsable)

echo $JOBID created

echo "Using the slurm facilities to wait for the job to start..."
srun --partition dev_cpuonly --dependency=after:$JOBID \
	-n 1 -t 1 \
	bash -c "echo waiting"


echo "Running a job step in a container inside the allocation at $JOBID"
srun --jobid=$JOBID --overlap \
     --container-image=alpine:latest \
     --container-mounts=/scratch:/scratch,/etc/slurm/task_prolog.hk:/etc/slurm/task_prolog.hk \
     -n 1 -t 1 grep PRETTY /etc/os-release

scancel $JOBID

# OUTPUT:
# Create the allocation and get the job ID
# This job runs on the host, no container
# 1889049 created
# Using the slurm facilities to wait for the job to start...
# srun: job 1889050 queued and waiting for resources
# srun: job 1889050 has been allocated resources
# waiting
# Running a job step in a container inside the allocation at 1889049
# pyxis: importing docker image: alpine:latest
# slurmstepd: error: pyxis: child 843191 failed with error code: 1
# slurmstepd: error: pyxis: failed to create container filesystem
# slurmstepd: error: pyxis: printing enroot log file:
# slurmstepd: error: pyxis:     mkdir: cannot create directory ‘/run/user/244691’: Permission denied
# slurmstepd: error: pyxis: couldn't start container
# slurmstepd: error: pyxis: if the image has an unusual entrypoint, try using --no-container-entrypoint
# slurmstepd: error: spank: required plugin spank_pyxis.so: task_init() failed with rc=-1
# slurmstepd: error: Failed to invoke spank plugin stack
# srun: error: hkn0013: task 0: Exited with exit code 1
