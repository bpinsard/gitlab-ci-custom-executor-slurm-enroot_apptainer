# Gitlab custom executor using Slurm + Enroot

This is a [custom executor for GitLab](https://docs.gitlab.com/runner/executors/custom.html)
written taking inspiration from https://github.com/ginkgo-project/gitlab-hpc-ci-cb 
and from Holger Obermaier's Slurm and enroot custom executor.

## Tests

To run all the tests, 
install all submodules with
```
git submodule update --init
```
(you can find alternatives [here](https://git-scm.com/book/en/v2/Git-Tools-Submodules))
and then use the command
``` bash
make test
```

### Unit tests

Unit tests require the [bats framework](https://github.com/bats-core)
installed as a collection of submodules.

### Integration tests

These integration tests expose the different interactions 
that we assume our software will have with the external system
(e.g., HoReKa).






