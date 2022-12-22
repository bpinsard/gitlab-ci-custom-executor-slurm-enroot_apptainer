# Gitlab custom executor using Slurm + Enroot

This is a [custom executor for GitLab](https://docs.gitlab.com/runner/executors/custom.html)
written taking inspiration from https://github.com/ginkgo-project/gitlab-hpc-ci-cb 
and from Holger Obermaier's Slurm and enroot custom executor.

## Debug

In some cases, the code looks at a variable called `CUSTOM_ENV_CE_DEBUG` 
(which should be possible to set as `CE_DEBUG` 
in the environment variable section of the CI "control panel"
on the gitlab instance web interface).
When that variable is set,
the scripts will save some results
or copy entire directories 
out of the builds dir so that 
the results can be inspected.

This debuggability feature might need to be expanded.

## Tests

To run all the tests, 
install all the necessary BATS submodules with
```
git submodule update --init
```
(you can find alternatives [here](https://git-scm.com/book/en/v2/Git-Tools-Submodules))
and then use the command
``` bash
make test JOBS=64
```
Notice that this will NOT run all the tests.
Some non-unit tests need to be run on the HoreKa cluster.

### Unit tests

Unit tests require the [bats framework](https://github.com/bats-core)
installed as a collection of submodules.

### Contract tests

These contract tests probe the different interactions 
that we assume our software will have with the external system
(e.g., HoreKa).


### End to end tests on HoreKa

In order to fully test the custom executor, 
we need to do the following steps.

Once:
- set up a custom executor with `gitlab-runner register` (once)
- set up the custom executor as a systemd service

Every time we run the pipeline:

- deploy the code to horeka, in the locations where the gitlab runner needs them
- make sure the custom executor is running (log into the horeka-ci loging node)
- trigger a CI pipeline with jobs that use the deployed custom executor on gitlab
  (via an api call?)
- optionally retrieve the status of the pipeline 



