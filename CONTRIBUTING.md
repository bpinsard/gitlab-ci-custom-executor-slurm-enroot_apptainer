# Development and maintenance of the custom executor code

## Contributing

A very minimal guide 
to the intended contribution workflow:

* **Testing**:  
  To contribute, please familiarize 
  with the bats test framework 
  and its various add-ons.
  Each piece of new code 
  needs to have a test 
  that motivates 
  why it needs to be there.

* **Bugs**:  
  In case bugs or problems are found, 
  a test should be created to reproduce the problem
  and then the problem should be corrected.

* **Merging**:  
  Before merging onto `main`,
  the code needs to be reviewed.
  Please make a pull request or a merge request,
  do not push immediately to `main`
  unless agreed otherwise.

* **Contacts**:  
  In case of questions,
  do not hesitate to contact 
  `michele.mesiti` *at* `kit.edu`.


## Development and Maintenance

### Debug

In some cases, the code looks at a variable called `CUSTOM_ENV_CE_DEBUG_LVL` 
(which should be possible to set as `CE_DEBUG_LVL` 
in the environment variable section of the CI "control panel"
on the gitlab instance web interface).
When that variable is set to a value
- greater than 0: the scripts will have a more verbose output
- greater than 1: the scripts will save some results
  or copy entire directories 
  out of the builds dir so that 
  the results can be inspected.

To debug the custom executor, 
one could try to set this variable
when triggering manually a pipeline.

This debuggability feature might need to be expanded.
If you find any issues with the runner,
please let us know.

To debug some test cases, 
it might make sense to temporarily comment out
the removal of the test directory 
in the teardown step,
in order to be able to inspect 
the temporary files and directories
that were created.

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
  (this might require to log into the horeka-ci login node,
  or have lingering enabled for the systemd service)
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
a number of tests of the deployed executors.
These try to test different features of the executor,
e.g. the production of artifacts, usage of containers,
multi-node mpi jobs and some combinations of these
for the Singularity/Apptainer, Enroot and "nocontainer" 
flavours of the executor.

At the beginning of the pipeline,
the jobs are run using a shell executor,
but at some point the code is deployed 
to a directory of your choice
(in the `deploy` stage)
and the later stages are run using the deployed
custom executor code.

In order for this to work:
depending on the machine where the tests are supposed to run,
set `.gitlab-ci-bwuc2.yml` or `.gitlab-ci-horeka.yml`
as the CI/CD configuration file on the GitLab CI web interface
(Settings -> CI/CD -> General Pipelines).
The difference between these files is only that they include
slightly different tests, that differ only 
in the choice of the partition
for a multi-node mpi job
(This might be done better in another way
but it is debatable).

### Setting up the runners for the pipeline

A number of runners must be set up on the host
where the pipeline is going to run.
Examples of the gitlab runner configuration file
(usually `$HOME/.gitlab-runner/config.toml`)
for which the pipeline can successfully run
are shown in the directory `gitlab-ci/gitlab-runner-config-examples`.
(tags are not visible in the configurations,
they need to be set from the GitLab server web interface)

Detailed setup steps:

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
  - `--env CI_WS=...` that should point 
    at the same directory that is used for the other runners;
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
  - `--limit 1` to make sure that the runner
    does not try to lunch multiple jobs at the same time
    on the shell executor
    (it is possible to do this safely,
    but this is not possible at the moment
    with the current pipeline).
    
  This runner will be used for 
  the first run of the test suite and the linting,
  for the update of the custom executor code
  that is necessary for the bootstrap
  (this is done int the test-deploy stage),
  and for downloading container images to test the `IMAGEFILE` feature.
  
- In order to test all the possible configurations
  of the custom executor,
  6 custom gitlab runners needs to be registered 
  and properly configured 
  so that they use the scripts in the test directory
  used in the test-deploy stage.
  Unfortunately, with the latest version of GitLab (>= 16.0)
  this requires some manual labor,
  as one needs to obtain *6 different registration tokens*
  from the GitLab server web interface
  (A single registration token for all the runners
  can be used with GitLab < 16.0).
  To register one runner based on the custom executor
  in a convenient way, 
  the command `./utils/gitlab-runner-register-wrapper.sh` 
  can be used.
  Suggestions:
  - The `--container-backend` option 
    can be used to specify `apptainer`, `enroot` and `none`
    each time, for each runner.
  - The `--use-slurm` flag can be used 
    with values "yes" and "no".
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
  
  The build directories that each of the runners use
  should be different, to make sure that 
  there are no intereferences. 
  This is taken care of at the `configure_exec` stage,
  where the build directory inside `CI_WS`
  is determined based on the name of the containerisation backend
  and the value of `CI_CONCURRENT_ID`
  (so that multiple jobs can be run at the same time
  by each runner independently)

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
    must have `slurm, nocontainer, horeka` tag.
  
  If the pipeline is run on BWUniCluster 2.0,
  the `horeka` tag should be changed to `bwuc2`
  (see the differences between `horeka-specific.yml`
  and `bwuc2-specific.yml`).
  
- Optionally, one would like to set up authentication for DockerHub
  both for Apptainer and for Enroot.
  This might be needed if one wants to 
  run the pipeline multiple times a day
  without hitting the pull rate limit.
  For this, one can set the `APPTAINER_DOCKER_USERNAME`
  and the `APPTAINER_DOCKER_PASSWORD` environment variables
  that will be used by default by Apptainer,
  and then use the following line 
  ```
  machine auth.docker.io login <username> password $CUSTOM_ENV_APPTAINER_DOCKER_PASSWORD
  ```
  in the `.config/enroot/.credentials` netrc file
  (see [the documentation](https://github.com/NVIDIA/enroot/blob/master/doc/cmd/import.md#usage)
  for Enroot's import command).

#### Quick remarks on concurrency
The custom executor code as it is 
should be able to work concurrently
and process more than one job at the time
without race conditions or conflicts.
This means that it should be possible
to register runners with these executors,
and set `concurrent` to a value higher than 1
in the global section of the runner configuration file.

The test suite of the custom executor 
has, though, limitations regarding concurrency.
The dependencies between the jobs are set correctly,
but the fact that the pipeline 
includes the deployment of the code
and other global filesystem or host-wide operations
on the machine that is used
makes it unsafe to run multiple pipeline at the same time,
i.e., if there are multiple pipelines in flight for this project 
(caused, e.g. by multiple pushes close in time)
they might interfere with each other.


  
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
- In order to inspect the state 
  of the custom executor queue after each test,
  one can temporarily comment out 
  the removal of the test directory 
  in the teardown function.
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

### Packaging

The scripts and this documentation 
can be collected into a `RPM` package
with the following command,
which uses `rpmbuild` under the hood:
```
make -f packaging/Makefile rpm
```
The information necessary for building the package
are in the `packaging` directory.
