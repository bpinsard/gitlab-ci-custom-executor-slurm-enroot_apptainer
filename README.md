# Gitlab custom executor using Slurm + Enroot

This is a [custom executor for GitLab](https://docs.gitlab.com/runner/executors/custom.html)
written taking inspiration from https://github.com/ginkgo-project/gitlab-hpc-ci-cb 
and from Holger Obermaier's Slurm and enroot custom executor.

## Usage

### Setup of the custom executor on HoreKa

### Gitlab CI setup

A gitlab runner needs to be registered on HoreKa
using the `gitlab-runner register` command,
(see the [official documentation](https://docs.gitlab.com/runner/register/)
for a general idea,
the invocation and launch of the gitlab runner 
depends on the configuration
of the system the runner is supposed to run on).

The `gitlab-runner register` command
invoked without options
will ask clearly for what is needed
in an interactive way,
i.e., the `gitlab-=ci coordinator` url,
the registration token 
(which can both be obtained 
in the "Runners" section 
of the CI/CD panel 
in the Settings page
of the project on the gitlab web interface),
the tags we want to give to the runner
(any job defined in the pipeline setup, 
e.g. the `.gitlab-ci.yml` file in the repository,
will be launched on the runner
if its tags are a subset of the runner tags),
and a description.

After that, one needs to manually modify the configuration file
(by default, `$HOME/.gitlab-runner/config.toml`)
and 

In this repository wrapper in `/utils/gitlab-runner-register-wrapper.sh`,
which streamlines the most tedious part 
of the registration of a runner that uses a custom executor,
removing the need to manually modify 
the gitlab runner configuration file.

Whether or not 

#### Environment variables

Remember to set the variable `CI_WS` 
to a path you have access to on HoreKa.
This can be done in [various ways](https://docs.gitlab.com/ee/ci/variables/).
This variable needs to be an absolute path
pointing to an existing directory in your home directory.

#### Job tags

In order for a particular job to use the custom executor,
one possible way is to use the `tags:` section.
The tags of the job need to be a subset of the tags 
with which the runner was set up.
The tags for a specific runner
only exist on the Gitlab web interface,
and can be changed there.

## Development and maintenance
### Debug

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

### Tests

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
Some tests which are more complex 
need to be run on the HoreKa cluster.

### Linting

`shellcheck` is used for linting.

#### Unit tests

Unit tests require the [bats framework](https://github.com/bats-core)
installed as a collection of submodules.

#### Contract tests

These contract tests probe the different interactions 
that we assume our software will have with the external system
(e.g., HoreKa).


#### End to end tests on HoreKa

In order to fully test the custom executor, 
we need to do the following steps.

Once:
- set up a custom executor with `gitlab-runner register` 

- set up the custom executor as a systemd service

Every time we run the pipeline:

- make sure the gitlab runner is running 
  (log into the horeka-ci login node)
- deploy the code to horeka, 
  in the locations where the gitlab runner needs them
  (this is part of the pipeline)
- start jobs that make use 
  of the custom executor
  (through the tag mechanism)

### Gitlab CI configuration (WORK IN PROGRESS)

The Gitlab CI configuration included in this repository
is made up of a number of stages
which include unit test, a test deployment,
a number of tests of the deployed executor
(this includes a job with artifacts, 
one in a container,
a multi-node job (<- TODO))

At the beginning of the pipeline,
the jobs are run using a shell executor,
but at some point the code is deployed 
(in the "test-deploy" stage)
and the later stages are run using the deployed
custom executor code.

In order for this to work:
- a "normal" executor needs to be registered
  (a shell executor would work just fine)
- a custom gitlab runner needs to be registered 
  and properly configured 
  so that it uses the scripts in the test directory
  used in the test-deploy stage.


