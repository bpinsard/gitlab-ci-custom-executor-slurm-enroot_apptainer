# GitLab custom executor using Slurm + Enroot/Singularity


![Pipeline Status](https://git.scc.kit.edu/hs2454/gitlab-ci-custom-executor-slurm-enroot_apptainer/badges/main/pipeline.svg)

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
(the `apptainer pull` command is used under the hood).

**Note:** it is not possible to execute root commands 
in Singularity containers on HoreKa or bwUnicluster 2.0.
With Enroot it is theoretically possible to use the `--root` option 
for the command `enroot start`, 
but it is not implemented at the moment.

Alternatively, if an image file or a sandbox directory
is already available on the system where the runners are launched,
it is possible to set the `IMAGEFILE` variable to that path,
and the custom executor will use it. 
Do not use the `IMAGEFILE` variable
with the `image:` option.

### Further customization of Apptainer behaviour

It is possible, by specifying a value for 
`APPTAINER_EXEC_OPTIONS`, to pass additional options 
to the `apptainer exec` command used to launch the container.
This can be used to mount additional directories from the host 
with the `--bind` option 
(e.g., `$TMPDIR` or the location 
of the chosen mpi installation), 
or to require support for gpus 
with the `--nv` or `--rocm` options.

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

#### Apptainer

Apptainer can use the `APPTAINER_DOCKER_USERNAME`
and `APPTAINER_DOCKER_PASSWORD` environment variables.
These can be set on the GitLabCI interface.
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

If subsequent jobs try use the same values for all the variables,
then the executor will try to schedule them on the same slurm allocation,
if there is enough time left in that allocation.
This would save the need to submit another job allocation 
and wait for it to start.
**Note**: at the moment the executor is not clever enough
to read the duration of the job from the `-t` or `--time` option
in `COMMANDS_OPTIONS_SBATCH`. 
To give this information to the configuration script,
please set the `JOB_TIME_SEC` variable for the job
to an appropriate value.
If the variable is not set, it is assumed 
that the job takes 600 seconds.



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
where Slurm, apptainer and enroot are available.

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

#### End to end tests on HoreKa or BWUniCluster

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
- a "non-custom" executor needs to be registered,
  tagged `shell`
  (a shell executor would work just fine),
  **adding the flags**:
  - `--env CI_TEST_CODE=/where/the/ce/code/lives` 
    (the `CI_TEST_CODE` variable
    determines where the custom executor code
    will be deployed);
  - `--env DEFAULT_PARTITION=...`
    (the `DEFAULT_PARTITION` variable
    determines what Slurm partition 
    will be used by default);
  - `--builds-dir $HOME/gitlab-runner/builds`,
    to make sure that this executor
    uses the same build directory 
    as the other executors under test
    (This is needed for a group of tests
    that require some files to stay
    in `$CI_BUILDS_DIR` between multiple tests,
    see `apptainer-imagefile-spec.yml` and `enroot-imagefile-spec.yml`;
  - `--cache-dir $HOME/gitlab-runner/cache`,
    for consistency (not strictly necessary at the moment).
    
  This runner will be used for 
  the first run of the test suite and the linting,
  for the update of the custom executor code
  that is necessary for the bootstrap
  (this is done int the test-deploy stage),
  and for downloading container images to test the `IMAGEFILE` feature.
  
- 3 custom gitlab runners needs to be registered 
  and properly configured 
  so that they use the scripts in the test directory
  used in the test-deploy stage.
  Unfortunately, with the latest version of GitLab (>= 16.0)
  this requires some manual labor,
  as one needs to obtain *3 different registration tokens*
  from the GitLab server web interface
  (A single registration token for all the runners
  can be used with GitLab < 16.0).
  To register one runner based on the custom executor
  in a convenient way, one can use the command
  `./utils/gitlab-runner-register-wrapper.sh`.
  Suggestions:
  - The `--container-backend` option 
    can be used to specify `apptainer`, `enroot` and `none`
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

  If the pipeline is going to be run on HoreKa, 
  one needs to change the pipeline definition file
  from `.gitlab-ci.yml` to `.gitlab-ci-horeka.yml`
  in Settings -> CI/CD -> General pipelines
  (on GitLab 15.10).
  If the pipeline is goint to be run on BWUniCluster 2.0,
  the pipeline is defined `.gitlab-ci-bwuc2.yml`.
  
  These two files differ only for the inclusion 
  of either an `horeka-specific.yml` 
  or an `bwuc2-specific.yml` file,
  which differ only in the definition 
  of the slurm partition to use to run the jobs.
  
  In order for the jobs in the pipeline
  (as it is now)
  to be picked up by the right runner,
  on HoreKa:
  - the runner registered with the `apptainer` backend
    must have `apptainer, slurm, horeka` tags,
  - the runner registered with the `enroot` backend
    must have `enroot, slurm, horeka` tags,
  - the runner registered with the `none` backend
    must have `slurm, slurm-only, horeka` tag.
  
  If the pipeline is run on BWUniCluster 2.0,
  the `horeka` tag should be changed to `bwuc2`
  (see the differences between `horeka-specific.yml`
  and `bwuc2-specific.yml`).
  
### Troubleshooting

- The CI job called `unit-test-parallel` hangs 
  and does not produce any output  
  Try to run the test suite manually on your machine,
  and then on HoreKa or BWUniCluster
  It has been successfully run with `make JOBS=64`
  on a 8-core machine.
  In the CI jobs 
  by default no option on stdout is produced,
  and instead the test results are written in a junit xml file.
  You can try to disable the production of the xml report
  and reactivate the stdout output.
- The test suite says "<N> tests not run" without any additional information  
  This is still an error, 
  a sign that something does not work as it should.
  The best course of action 
  is to try and point out the (hopefully small number of)
  tests that fail, and check them step by step,
  possibly inserting additional debugging statements
  in the test code.
- General: The pipeline fails on HoreKa or on BWUniCluster  
  Apart from the obvious reasons, like a bug that broke the code,
  it could be that the executors have not been set up 
  according to the instructions above
  (the `shell` executor is the most complex to set up,
  since there is no wrapper helping with sensible defaults).
  This is most likely if the test suite runs without errors
  on your laptop or on a login node.
  Make sure that the paths in the `environment` section
  of the `config.toml` file are in agreement for all the runners 
  (this is crucial for those groups of tests that require consistency,
  e.g., the tests related to the `IMAGEFILE` feature).

### Test coverage

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
