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
- the runner: an abstract resource that can run CI jobs.
  A runner can be created/registered for a GitLab repository,
  for a GitLab group or a GitLab instance.
- the executor: the underlying concrete  mechanism 
  that will execute the CI jobs
  More info can be obtained [here](https://docs.gitlab.com/runner/executors/)
- the custom executor: a custom version of the executor,
  composed of a number of scripts
  representing the customization hooks of the runner.
  More info can be obtained [here](https://docs.gitlab.com/runner/executors/custom.html)

### GitLab CI setup: obtaining the custom executor code

The of the custom executor needs to be copied to the hpc system. 
There are a few ways to do this.
Either:
- This code might be available on the system,
  in the system directories
  (see system documentation).
  This is by far the simplest option
- Clone this repository on the system.
  This is the best option if you think 
  you will have to modify the code;

Alternatively, a  tarball with all the necessary code
can be produced using the `Makefile` 
in the `packaging` directory extract it on the system.
It is also produced as an artifact
by one of the jobs in the CI pipeline
of this project.


### GitLab CI setup: Register the runner
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
  (retrieve this from the CI runner setting web page
  or from the registration procedure);
- a description, or name, for the runner
- the containerisation backend 
  that we might be interested in using,
  i.e., enroot, apptainer or none
  (this makes no difference
  for a job that does not use any containers)
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

#### Important: Runner tags and job tags

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
in the CI/CD configuration file 
(i.e., typically, `.gitlab-ci.yml`).

#### Important: Allowed committers for an executor

Since the GitLab runner process 
is run with the permissions of the user launching it,
particular care must be taken
to make sure that malicious actors 
are not able to run arbitrary code.

Please have a thorough look 
at the [security implications](https://docs.gitlab.com/runner/security/)
of self hosted runners.

As an additional security measure,
the custom executor can make use 
of a list of allowed committer usernames.

The list of allowed committers must be saved into a file
that belongs to the user running the executor
and is not writable from others.
The path of the file is specified in the `CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE`.


If `CUSTOM_ENV_CI_ALLOWED_COMMITTERS_FILE` is empty or not set,
then the `GITLAB_USER_LOGIN` variable must coincide 
with the value of the `USER` variable.


Notice that the `GITLAB_USER_LOGIN` variable 
can be spoofed 
(it can be set manually when triggering the pipeline,
but the value seen by the runner/executor
cannot be modified from inside the pipeline file).

The script `gitlab-runner-register-wrapper.sh` 
takes also care of setting this file up for you,
asking the relevant information.


#### Workspace for the custom executor

In order to use the custom executor,
the variable `CI_WS` must be set 
to a path you have access to 
(on the system you want the runner to live on).

The recommended way is to define it 
in the private configuration of the custom executor,
on the machine where the runner is registered.
The `gitlab-runner-register-wrapper.sh` script
sets it to a reasonable default (`$HOME/gitlab-runner/<container-backend>`).

Alternatively, it can be done in [various ways](https://docs.gitlab.com/ee/ci/variables/),
e.g. [in the `.gitlab-ci.yml` file](https://docs.gitlab.com/ee/ci/variables/#define-a-cicd-variable-in-the-gitlab-ciyml-file)
in [web interface](https://docs.gitlab.com/ee/ci/variables/#define-a-cicd-variable-in-the-ui).
or in the `environment` section of the configuration file
of the runner (typically, `$HOME/.gitlab-runner/config.toml`).


This variable needs to be an absolute path
pointing to directory 
you have write privileges on.

#### The plain `gitlab-runner register` command

The `gitlab-runner register` command 
can be used to register runners
(see the [official documentation](https://docs.gitlab.com/runner/register/)
for a general idea,
the invocation and launch of the GitLab runner 
depends on the configuration
of the system the runner sits on).

After that, one may need to manually modify the configuration file
(by default, `$HOME/.gitlab-runner/config.toml`),
/unless all the necessary command line options/
have been passed to the invocation 
of `gitlab-runner register`.

To achieve parity with 
what `gitlab-runner-register-wrapper` does,
typically one has to invoke 
the command `gitlab-runner register`
and modify the configuration file
in multiple places,
in particular adding the paths to all the scripts 
and setting environment variables
(these settings are generally overlooked
in the standard invocation 
of `gitlab-runner register`).

### CI jobs in containers on HoreKa and bwUniCluster 2.0

The custom executor can use [Singularity/Apptainer](https://apptainer.org/)
or [Enroot](https://github.com/NVIDIA/enroot) to run jobs in containers
(this relies on Singularity/Apptainer or Enroot to be installed
on the HPC system in use).

In order to use those, make sure that:
- either the `image:` tag of the CI job 
  is set in the same format as Singularity/Apptainer or Enroot expect it.
  Both Apptainer and Enroot do support image specification in a format like
  `docker://debian:latest`.
- or an `IMAGEFILE` variable is set 
  that points to an existing Apptainer container 
  or to an existing `.sqsh` image file for Enroot.

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

DockerHub has a pull rate limiting.
For non authenticated users it is 100 pulls *per IP address* every 6 hours,
while for authenticated users it is 200 pulls *per account* every 6 hours.
If you are hitting a pull rate limit, consider authenticating.

Singularity and Enroot have different authentication mechanisms. 

DockerHub access tokens can be configured to have a smaller scope,
and according to [the documentation](https://docs.docker.com/docker-hub/access-tokens/)
they can be used in any place where a password is needed.

**NOTE: It is a very dangerous practice to save access credentials
in a software repository, e.g. in the .gitlab-ci.yml file.
Use one of the numerous alternatives.**

#### Apptainer

Apptainer [can use](https://apptainer.org/docs/user/latest/docker_and_oci.html#environment-variables)
the `APPTAINER_DOCKER_USERNAME`
and `APPTAINER_DOCKER_PASSWORD` environment variables.
These can be set on the GitLabCI interface
and will be then used by the custom executor.

Alternatively, it is possible to use 
[the `apptainer remote login` command](https://apptainer.org/docs/user/latest/docker_and_oci.html#apptainer-cli-remote-command)
on the machine hosting the runner.
This will cause the credentials 
to be stored in the home directory.

Additional relevant information can be found [here](https://apptainer.org/docs/user/latest/endpoint.html#managing-oci-registries).

##### Enroot

Enroot uses `curl` under the hood, 
which uses a `netrc` file.
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
The allocation is not reused
if the variable `REUSE_WORKSPACE` is set to `OFF`.
**Note**: at the moment the executor is not clever enough
to read the duration of the job from the `-t` or `--time` option
in `COMMANDS_OPTIONS_SBATCH`. 
To give this information to the configuration script,
please set the `JOB_TIME_SEC` variable for the job
to an appropriate value.
If the variable is not set, it is assumed 
that the job takes 600 seconds.



## Development 

To modify the code in this repository,
please have a look at [`CONTRIBUTING.md`](./CONTRIBUTING.md)
for a general introduction, 
set up of the development environment
and contribution guidelines.
