# GitLab custom executor using Slurm + Enroot/Singularity

This is a [custom executor for GitLab](https://docs.gitlab.com/runner/executors/custom.html)
written taking inspiration from https://github.com/ginkgo-project/gitlab-hpc-ci-cb 
and from Holger Obermaier's Slurm and Enroot custom executor.

## What it does

It allows the user to launch jobs from GitLab CI 
on a SLURM-based HPC cluster (only HoreKa tested so far).
If sufficient conditions are met,
multiple CI jobs can be queued on a single Slurm Job.
The runner will create a new Slurm allocation for a job 
if it cannot determine whether a suitable existing allocation exists.

The user can influence the parameters of the Slurm Job allocation
by setting [`sbatch` input variables](https://slurm.schedmd.com/sbatch.html)
in the CI configuration file,
and by setting the environment variable `COMMAND_OPTIONS_SBATCH` 
to a string of `sbatch` command line parameters 
(this is needed to set the number of tasks, for example).

## Usage

### GitLab CI setup - background 

A GitLab runner needs to be registered on HoreKa
using the `gitlab-runner register` command,
(see the [official documentation](https://docs.gitlab.com/runner/register/)
for a general idea,
the invocation and launch of the GitLab runner 
depends on the configuration
of the system the runner is supposed to run on).

The `gitlab-runner register` command
invoked *without options*
will ask clearly for what is needed
in an interactive way,
i.e., the `gitlab-ci coordinator` url,
the registration token 
(which can both be obtained 
in the "Runners" section 
of the CI/CD panel 
in the Settings page
of the project on the gitlab web interface),
the tags we want to give to the runner
and a description.

After that, one needs to manually modify the configuration file
(by default, `$HOME/.gitlab-runner/config.toml`)
and add the location of the scripts
that make up the custom driver.

#### What are runner tags?

Tags are a mechanism which allows us 
to choose which runner can process a given job
in a pipeline.
A jobs defined in a pipeline setup
(e.g. the `.gitlab-ci.yml` file in the repository)
will be launched on a runner
if the tags of the job are a subset of the runner.

### GitLab CI setup - the wrapper

In this repository 
a wrapper for the command `gitlab-runner register` is included,
`utils/gitlab-runner-register-wrapper.sh`,
which streamlines the most tedious parts
of the registration of a runner that uses 
the custom executor written here,
removing the need to manually modify 
the GitLab runner configuration file
while using some reasonable defaults.

The command
``` bash
$ utils/gitlab-runner-register-wrapper.sh --help
```
explains the usage of the wrapper.

#### Workspace for the custom executor

In order to use the custom executor,
the variable `CI_WS` must be set 
to a path you have access to on HoreKa.

The recommended way is to define it 
in the private configuration of the custom executor,
on the machine where the runner is registered.
The `gitlab-runner-register-wrapper.sh` scripts
provides a way to set it.
Alternatively, it can be done in [various ways](https://docs.gitlab.com/ee/ci/variables/),
e.g. [in the `.gitlab-ci.yml` file](https://docs.gitlab.com/ee/ci/variables/#define-a-cicd-variable-in-the-gitlab-ciyml-file)
or in [web interface](https://docs.gitlab.com/ee/ci/variables/#define-a-cicd-variable-in-the-ui).

This variable needs to be an absolute path
pointing to an existing directory 
you have write privileges on.


#### Job tags

In order for a particular job to use the custom executor,
one possible way is to use the `tags:` section.
The tags of the job need to be a subset of the tags 
with which the runner was set up.
The tags for a specific runner
are set at the registration step,
but can be changed on the  GitLab web interface.

### CI jobs in containers on HoreKa

The custom executor can use [Singularity/Apptainer](https://apptainer.org/)
or [Enroot](https://github.com/NVIDIA/enroot) to run jobs in containers
(this relies on Singularity/Apptainer or Enroot to be installed
on HoreKa).

In order to use those, make sure you set the `image:` tag 
of the CI job in the same format as Singularity/Apptainer or Enroot expect it.

Singularity is quite more flexible and it will accept 
the `name:tag` format as an image specification,
while Enroot needs a 
[more precise specification](https://github.com/NVIDIA/enroot/blob/master/doc/cmd/import.md#usage).

#### Authentication to DockerHub

DockerHub has a pull rate limiting in place of 200 pulls every 6 hours.
For non authenticated users it applies to *the IP address*,
while for authenticated users it applies to a single user account.
If you are hitting a pull rate limit, consider authenticating.

Singularity and Enroot have different authentication mechanisms. 

DockerHub access tokens can be configured to have a smaller scope,
and according to [the documentation](https://docs.docker.com/docker-hub/access-tokens/)
they can be used in any place where a password is needed.

TODO: Elaborate [...]

Singularity can use the `SINGULARITY_DOCKER_USERNAME`
and `SINGULARITY_DOCKER_PASSWORD`. 
These can be set on the GitlabCI interface. 

Additionally, Singularity can store credentials in its cache file.



##### Enroot




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
If you find any issues with the runner,

### Linting

`shellcheck` is used for linting.


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

Unit tests require the [bats framework](https://github.com/bats-core)
installed as a collection of submodules.

#### Unit Tests

A large number of unit tests have been written,
that rely on mocks of various command line utilities
to run on any machine that does not have 
`slurm`, `Singularity` or `Enroot`.

#### Contract tests

These contract tests probe the different interactions 
that we assume our software will have with the external system
(e.g., HoreKa).

#### End to end tests on HoreKa

In order to fully test the custom executor, 
we need to do the following steps.

Once:
- set up a custom executor with `gitlab-runner register`,
  or using the wrapper
- set up the custom executor as a systemd service,
  or just just launch it as a process in a tmux session.
  Notice that in order to have the systemd service running
  you need either to have a session active
  or to have *lingering* enabled.
  To have *lingering* enabled, 
  please ask a System Administrator.

Every time we run the pipeline:

- make sure the gitlab runner is running 
  (log into the horeka-ci login node)
- deploy the code to horeka, 
  in the locations where the gitlab runner needs them
  (this is part of the pipeline)
- start jobs that make use 
  of the custom executor
  (through the tag mechanism)

### GitLab CI configuration

The GitLab CI configuration included in this repository
is made up of a number of stages
which include unit test, a test deployment,
a number of tests of the deployed executor
(this includes a job with artifacts, 
one in a container,
a multi-node job 

At the beginning of the pipeline,
the jobs are run using a shell executor,
but at some point the code is deployed 
(in the "test-deploy" stage)
and the later stages are run using the deployed
custom executor code.

In order for this to work:
- a "normal" executor needs to be registered,
  tagged `shell`
  (a shell executor would work just fine)
- a custom gitlab runner needs to be registered 
  and properly configured 
  so that it uses the scripts in the test directory
  used in the test-deploy stage.
  For this, one can use 
  ``` bash
  ./utils/gitlab-runner-register-wrapper.sh --tags=slurm --container-backends=both
  ```


### Test coverage

In case one installs it on the machine 
on which the tests are run,
[`bashcov`](https://github.com/infertux/bashcov) 
can be used to collect coverage information.

The `test-and-coverage` target in the `Makefile`
is provided with that aim.

Unfortunately, `bashcov` does not seem 
to interact perfectly
with `bats`, and some tests hang while running,
causing (possibly) erratic and nonsensical coverage information.




