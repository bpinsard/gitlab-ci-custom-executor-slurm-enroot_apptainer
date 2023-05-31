# GitLab custom executor using Slurm + Enroot/Singularity

This is a [custom executor for GitLab](https://docs.gitlab.com/runner/executors/custom.html)
written taking inspiration from https://github.com/ginkgo-project/gitlab-hpc-ci-cb 
and from Holger Obermaier's Slurm and Enroot custom executor.

## What it does

It allows the user to launch jobs from GitLab CI
on a SLURM-based HPC cluster 
(only HoreKa and BWUniCluster 2.0 tested so far).
The `gitlab-runner` process is launched 
and resides on the login nodes, 
and requests resources via Slurm on the compute nodes 
to run all the stages of the CI/CD jobs.
If /sufficient/ conditions are met,
multiple CI/CD jobs can use a single Slurm job allocation.
The runner will create a new Slurm allocation for a CI/CD job 
if it cannot find a suitable existing allocation.
If a Slurm job allocation is idling for some amount of time
(100 seconds, but this can be changed) 
it will terminate itself in order to avoid wasting resources.

## Usage
### GitLab CI setup: terminology 

For convenience, a brief explanation 
of the terms used in this documentation:
More info can be obtained [here](https://docs.gitlab.com/runner/)

- the `gitlab-runner` executable. 
  It is a standalone program that 
  manages the communication with the GitLab instance,
  and provides some standard mechanisms of execution
  and customization hooks.
- the runner: a resource that can run CI jobs.
  A runner can be created/registered for a GitLab repository,
  for a GitLab instance or a GitLab group. 
- the executor: the underlying mechanism 
  that will concretely execute the CI jobs
  More info can be obtained [here](https://docs.gitlab.com/runner/executors/)
- the custom executor: a custom version of the executor,
  composed of a number of scripts
  representing the customization hooks of the runner.
  More info can be obtained [here](https://docs.gitlab.com/runner/executors/custom.html)

### GitLab CI setup: installing the custom executor code

To set up this executor on a HPC system,
either:
- clone this repository on the system,
- make sure this code is available on the system,
  in the system directories
- create a  tarball with all the necessary code
  (which can be produced using the `Makefile` 
  in the `packaging` directory),
  and extract it on the system.

### GitLab CI setup: runner registration
To register a new runner
make use of the script named
`gitlab-runner-register-wrapper.sh`,
which is available in the `utils` directory
of this repository.
As the name suggests, 
it is a wrapper around the `gitlab-runner register` command
that streamlines the registration of a runner 
based on the scripts in this repository.

To register a runner for a repository,
navigate to the web interface of your GitLab instance,
to the repository you want, and to Settings -> CI/CD -> Runners.

Invoked *without options*
will ask clearly for what is needed
in an interactive way.
The most important inputs and options are:
- the `gitlab-ci coordinator` URL,
  i.e., the URL of the server 
  where the repository live
  (retrieve this from the CI runner setting web page);
- the project registration token,
  needed by the runner to query 
  the gitlab server for CI jobs
  (retrieve this from the CI runner setting web page);
- a description, or name, for the runner
- the tags we want to give to the runner (optional)
- the containerisation backend 
  that we might be interested in using
  (This is used only 
   if we have an `image:` section 
   in the definition of the CI job)
- the default Slurm partition that we want to use 
  for our jobs.
Other options are available, 
but the wrapper should propose 
reasonable values for those.

The command
``` bash
$ ./utils/gitlab-runner-register-wrapper.sh --help
```
gives a more detailed description 
of the available options.

For the use cases 
that are not covered by the wrapper,
it is still possible to either use 
the plain `gitlab-runner register` command
and/or to modify the GitLab runner configuration file
that by default lives in `$HOME/.gitlab-runner/config.toml`.

#### Runner tags and job tags

Tags are a mechanism which allows 
to choose which runner can process a given job
in a pipeline.

A runner will accept and execute 
a job defined in a pipeline setup
(e.g. the `.gitlab-ci.yml` file in the repository)
in two cases:
- either the tags of the job are 
  a subset of the tags of the runner
- or the runner is allowed to execute untagged jobs.

The tags of the runner are defined 
at the runner registration stage
(and can be later changed on the GitLab web interface),
while the tags for the jobs are set
in the `tags:` section of the job definition
in the CI/CD configuration file (i.e., typically, `.gitlab-ci.yml`).

#### Workspace for the custom executor

In order to use the custom executor,
the variable `CI_WS` must be set 
to a path you have access to 
(on the system you want the runner to live on).

The recommended way is to define it 
in the private configuration of the custom executor,
on the machine where the runner is registered.
The `gitlab-runner-register-wrapper.sh` script
sets it to a reasonable default (`$HOME/gitlab-runner/`).

Alternatively, it can be done in [various ways](https://docs.gitlab.com/ee/ci/variables/),
e.g. [in the `.gitlab-ci.yml` file](https://docs.gitlab.com/ee/ci/variables/#define-a-cicd-variable-in-the-gitlab-ciyml-file)
in [web interface](https://docs.gitlab.com/ee/ci/variables/#define-a-cicd-variable-in-the-ui).
or in the `environment` section of the configuration file
of the runner (typically, `$HOME/.gitlab-runner/config.toml`).

This variable needs to be an absolute path
pointing to an existing directory 
you have write privileges on.

#### The plain `gitlab-runner register` command

The `gitlab-runner register` command 
can be used to register runners
(see the [official documentation](https://docs.gitlab.com/runner/register/)
for a general idea,
the invocation and launch of the GitLab runner 
depends on the configuration
of the system the runner sits on).

After that, one generally needs to manually modify the configuration file
(by default, `$HOME/.gitlab-runner/config.toml`),
unless all the necessary command line options
have been passed to the invocation 
of `gitlab-runner register`.

To achieve parity with 
what `gitlab-runner-register-wrapper` does,
typically one has to invoke 
the command `gitlab-runner register`
and modify the configuration file
in multiple places,
in particular adding the paths to all the scripts 
and setting environment variables.

### CI jobs in containers on HoreKa and bwUniCluster 2.0

The custom executor can use [Singularity/Apptainer](https://apptainer.org/)
or [Enroot](https://github.com/NVIDIA/enroot) to run jobs in containers
(this relies on Singularity/Apptainer or Enroot to be installed
on the HPC system in use).

In order to use those, make sure you set the `image:` tag 
of the CI job in the same format as Singularity/Apptainer or Enroot expect it.
Both Apptainer and Enroot do support image specification in a format like
`docker://debian:latest`.

The format for the image specification for Enroot is described 
[here](https://github.com/NVIDIA/enroot/blob/master/doc/cmd/import.md#usage)
(the `enroot import` command is used under the hood),
while the one for Apptainer is described
[here](https://apptainer.org/docs/user/main/cli/apptainer_pull.html)
(the `singularity pull` command is used under the hood).

**Note:** it is not possible to execute root commands 
in Singularity containers on HoreKa or bwUnicluster 2.0.
With Enroot it is theoretically possible to use the `--root` option 
for the command `enroot start`, 
but it is not implemented at the moment.


### Authentication to DockerHub

When using images with uri starting with `docker://`,
the image will be pulled from DockerHub (if it is not cached).

DockerHub has a pull rate limiting in place of 200 pulls every 6 hours.
For non authenticated users it applies to *the IP address*,
while for authenticated users it applies to a single user account.
If you are hitting a pull rate limit, consider authenticating.

Singularity and Enroot have different authentication mechanisms. 

DockerHub access tokens can be configured to have a smaller scope,
and according to [the documentation](https://docs.docker.com/docker-hub/access-tokens/)
they can be used in any place where a password is needed.

**NOTE: It is a very dangerous practice to save access credentials
in a software repository, e.g. in the .gitlab-ci.yml file.
Use one of the numerous alternatives.**

#### Singularity

Singularity can use the `SINGULARITY_DOCKER_USERNAME`
and `SINGULARITY_DOCKER_PASSWORD` environment variables.
These can be set on the GitLabCI interface.
Additionally, Singularity can store credentials in its cache file.

More information can be found [here](https://singularity-userdoc.readthedocs.io/en/latest/singularity_and_docker.html#authentication-in-the-environment).

##### Apptainer (newer version of Singularity)

Relevant information can be found [here](https://apptainer.org/docs/user/latest/endpoint.html#managing-oci-registries).

##### Enroot

Relevant information about enroot's authentication method,
is available at the [documentation of the enroot import command](https://github.com/NVIDIA/enroot/blob/master/doc/cmd/import.md).


### Slurm allocation settings

The user can influence the parameters of the Slurm Job allocation
by setting [`sbatch` input variables](https://slurm.schedmd.com/sbatch.html)
in the CI configuration file,
and by setting the environment variable `COMMAND_OPTIONS_SBATCH` 
to a string of `sbatch` command line parameters 
(this is needed to set the number of tasks, for example).

## Development and maintenance of the custom executor code

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
please let us know.

### Linting

`shellcheck` is used for linting.
The command `make shellcheck`
will:
- download and install the 
  `shellcheck` binary
  in the current repository
- run `shellcheck` on all 
  the files in the repository
  (including test files,
  not including test depencencies).

### Tests

Unit tests require the [BATS framework](https://github.com/bats-core)
installed as a collection of submodules.
The submodules can be installed with
```
git submodule update --init
```
(you can find alternatives [here](https://git-scm.com/book/en/v2/Git-Tools-Submodules))
and then 
to run the tests
use the command
``` bash
make test JOBS=64
```
Notice that *this will not necessarily run all the tests*.
Some tests which are more complex 
are meaningful only when run on the HoreKa cluster,
where Slurm, singularity and enroot are available.

#### Unit Tests

A large number of unit tests have been written,
that rely on mocks of various command line utilities
to run on any machine that does not have 
`slurm`, `Singularity` or `Enroot`.
These will always be run when running `make test`.

#### Contract tests

These contract tests probe the different interactions 
that we assume our software will have with the external system
(e.g., HoreKa). These needs to be run on HoreKa.

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

### Configuration of the test pipeline on GitLab CI

**Note: This might be streamlined in the future.**

The GitLab CI configuration included in this repository
is made up of a number of stages
which include unit tests, a test deployment,
a number of tests of the deployed executor.
These try to test different features of the executor,
e.g. the production of artifacts, usage of containers,
multi-node mpi jobs and some combinations of these
for the Singularity/Apptainer, Enroot and "SLURM-only" 
flavours of the executor.

At the beginning of the pipeline,
the jobs are run using a shell executor,
but at some point the code is deployed 
to a directory of your choice
(in the "test-deploy" stage)
and the later stages are run using the deployed
custom executor code.

In order for this to work:
- depending on the machine where the tests are supposed to run,
  set `.gitlab-ci-bwuc2.yml` or `.gitlab-ci-horeka.yml`
  as the CI/CD configuration file on the GitLab CI web interface
  (Settings -> CI/CD -> General Pipelines).
  The difference between these files is only that they include
  slightly different tests, that differ only 
  in the choice of the partition
  for a multi-node mpi job.
- a "normal" executor needs to be registered,
  tagged `shell`
  (a shell executor would work just fine),
  adding the flags:
  - `--env CI_TEST_CODE=/where/the/ce/code/lives` 
    (the `CI_TEST_CODE` variable
    determines where the custom executor code
    will be deployed);
  - `--env DEFAULT_PARTITION=...`
    (the `DEFAULT_PARTITION` variable
    determines what Slurm partition 
    will be used by default);
  This runner will be used for 
  the first run of the test suite and the linting,
  and for the update of the custom executor code
  that is necessary for the bootstrap
  (this is done int the test-deploy stage)
- 3 custom gitlab runners needs to be registered 
  and properly configured 
  so that they use the scripts in the test directory
  used in the test-deploy stage.
  Unfortunately, this requires some manual labor,
  as one needs to obtain *3 different registration tokens*
  from the GitLab server web interface.
  To register one runner based on the custom executor
  in a convenient way, one can use the command
  `./utils/gitlab-runner-register-wrapper.sh`.
  Suggestions:
  - The `--container-backend` option 
    can be used to specify `singularity`, `enroot` and `none`
    each time, for each runner.
  - The `--registration-token` option can be used 
    to pass the registration tokens obtained 
    from the GitLab server web interface.
  - The `--name` option can be used to give a name 
    to each one of the runners, *which is important 
    to distinguish them from each other*
    in the GitLab server web interface
  After each runner has been registered,
  tags can be assigned to it 
  from the GitLab server web interface
  (where each runner can be edited independently).

  In order for the jobs in the pipeline
  to be picked up by the right runner:
  - the runner registered with the `singularity` backend
    must have `singularity, slurm` tags,
  - the runner registered with the `enroot` backend
    must have `enroot, slurm` tags,
  - the runner registered with the `none` backend
    must have `slurm, slurm-only` tag.
  
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

## Packaging

The scripts and this documentation 
can be collected into a `RPM` package
with the following command,
which uses `rpmbuild` under the hood:
```
make -f packaging/Makefile rpm
```
The information necessary for building the package
are in the `packaging` directory.
