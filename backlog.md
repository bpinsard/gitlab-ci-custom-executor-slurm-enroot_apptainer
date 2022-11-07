# Feature backlog and discussion

This file contains a list of features 
and points to the tests 
where each of the features is tested.

Note: we might need to run experiments 
on the systems we are interacting with
(both the gitlab stack and the hpc cluster)
to clarify some aspects of that.

## Functional

### Allocation manager

- [X] allocation manager should die when set 
- [ ] allocation manager should die gracefully 
- [X] allocation manager should pick up jobs and execute them
- [X] submitting jobs to the allocation manager 
- [X] the allocation manager should give back stdin and stdout
  (in the same file for simplicity)


### configure.sh
Preparation of the slurm allocation was done here,
and the information on how to reach it 
were saved in a json that contains an environment section,
so that in subsequent steps it is available through environment variables.

Here we need to create the slurm allocation
with the right parameters
start the "allocation manager" here, 
make the "allocation manager" reachable.

Considerations:

- variables (which might be used to select slurm resources)
  are presented to this script by the runner prepended with
  `CUSTOM_ENV`.
  The right ones (starting with SLURM)
  need to be renamed so that sbatch can pick them up.
- unfortunately `sbatch` cannot take all the job parameters
  as environment variables.
  For this reason, we need to provide a way to pass parameters
  to the sbatch invocation.

Features:

- [X] use `sbatch` with --container-image when a container image is required
- [ ] manage correctly mount options when a container image is required
  NOTE: this might need adjustments as we go along.
  - [X] mount the prolog stuff (from the [container docs][horeka-cont-docs])
  - [X] mount /scratch (from the [container docs][horeka-cont-docs])
  - [ ] mount the workspace for the allocation manager 
    (otherwise it will not be reachable)
- [X] start the allocation manager in the config phase 
      The allocation already comprises a container if needed.
- [X] pass input variables on to sbatch
- [ ] pass content of variable `COMMAND_OPTIONS_SBATCH` to `sbatch` invocation
- [ ] when `COMMAND_OPTIONS_SBATCH` is not defined, do lament
- [ ] use reasonable defaults for `sbatch` invocation 
      when `COMMAND_OPTIONS_SBATCH`not set 
- [ ] `job_env` should contain the information needed to next steps
 


### prepare.sh
Preparation of the image/container is done here 

### run.sh
- `prepare_script`
   This might need to run in the allocation.
- `get_sources`
   it needs to run outside the container,
   since `git` might not be available inside,
   but needs to be able to get the code in a place visible to the allocation.
   It also needs access to network.
- `restore_cache`
   it needs to be able to run outside the container,
   since it needs to see the `gitlab_runner` executable
- `download_artifacts`
   it needs to be able to run outside the container,
   since it needs to see the `gitlab_runner` executable
- `step_*`
   A group of files, that needs to be run inside the allocation 
   and the container
- `build_script`
   This needs to run in the container in the allocation
- `step_*`
   A group of files, that needs to be run inside the allocation 
   and the container (yes, this is repeated after `build_scritpt`)
- `after_script`
   This is run inside the container now (in the enroot executor),
   so this will go inside the allocation
- `archive_cache` OR `archive_cache_on_failure`
   I suspect this needs to run outside the container,
   since so far cache operations need to see the `gitlab_runner` executable
   (see `restore_cache`)
- `upload_artifacts_on_success` OR `upload_artifacts_on_failure`
   I suspect this needs to run outside the container,
   since so far artifact operations need to see the `gitlab_runner` executable
- `cleanup_file_variables`
   At the moment this is done in the container.
   The file-based environment variables are supposedly 
   THIS NEEDS TO BE TESTED

## Diagnostics
- should check the existence of the programs used
- should check the right environment variables are set up 
- when a step fails, it should give information about that

## Considerations
- It is not clear to me what is the difference 
  between using `sbatch --container` as an option
  or `sbatch --container-image`, 
  or creating the image manually and then loading it into enroot
  (but then this might not work when running on multiple nodes) 
- when running on multiple nodes
  in a container,
  it is not clear how to have a portable method
  (e.g., one that is independent of the MPI implementation used).
  I have found no precise information for enroot,
  but this is what one should do with Singularity and OpenMPI:
  https://docs.sylabs.io/guides/3.3/user-guide/mpi.html

  OpenMPI processes needs to talk to the ORTE Daemon
  that needs to be started automatically.
  
  In the case of Enroot, 
  apparently an environment variable
  can be used to tell the OpenMPI runtime
  how to start orted:
  https://github.com/NVIDIA/enroot/issues/49
  This unfortunately does not seem to work 
  on HoReKa (for multiple nodes).
  
  
  
- preparation of the allocation and of the image
  is done in two different steps at the moment
  (in the two slurm/enroot driver)
  This might actually need to change now.

## Ideas
- test bootstrapping: testing the custom executor 
  on the custom executor itself?


[horeka-cont-docs]: https://www.nhr.kit.edu/userdocs/horeka/containers/#slurm-integration
