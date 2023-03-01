# Gitlab CI notes

## Gitlab executors for slurm
- Holger's enroot solution
  - Already used, works, "deployed"
- Holger's SLURM solution
  - Not deployed
  - does not use containers (easy fix)
- ginkgo project's solution
  https://github.com/ginkgo-project/gitlab-hpc-ci-cb
  - fails when using an image that does not contain git
    (easy fix)
  - does not reuse SLURM allocations (AFAIK)
- HZDR Gitlab HPC runner
  Experimental?
  https://gitlab.hzdr.de/fwcc/gitlab-hpc-driver.git
- Exascale Computing Project
  Cannot find the source code (yet)
  but here is the documentation - TODO: Read
  https://ecp-ci.gitlab.io/docs/ci-users/ci-batch.html
- NHR@FAU
  https://hpc.fau.de/systems-services/documentation-instructions/special-applications-and-tips-tricks/continuous-integration/
- DKRZ
  https://docs.dkrz.de/doc/software%26services/gitlab-runner.html
- Jacamar-ci
  https://pkg.go.dev/gitlab.com/ecp-ci/jacamar-ci


    
## Gitlab Pipelines

- Is there a way to have multiple pipelines in a project that run individually (e.g. to build with different compilers)?  
  **ANSWER:** several possible workarounds in the [official documentation](https://docs.gitlab.com/ee/ci/pipelines/pipeline_architectures.html)
- Gitlab runner on Horeka with shell executor: you can process stuff on the compute node e.g. with `srun` and the runner waits for the execution of this command. Can you do this with a full batch script also?  
  **ANSWER:** `sbatch` has the option `--wait` to do exactly this. Alternatively, `srun [options] ./my_script.sh` will also exectue `my_script.sh` in the working directory.
- In a Gitlab pipeline, artifacts are used to keep files from one stage and pass it on to the other stages. During this process, do they stay on the file system, or are they uploaded at the end of the first stage and downloaded at the beginning of the second stage?



