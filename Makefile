

test:
	./tests/bats/bin/bats --jobs $(JOBS) -T --filter-tags !serial tests/*
	./tests/bats/bin/bats -T --filter-tags serial tests/*

test-report-parallel:
	./tests/bats/bin/bats --jobs $(JOBS) --formatter junit --filter-tags !serial tests/* > report-parallel.xml

test-report-serial:
	./tests/bats/bin/bats --formatter junit --filter-tags serial tests/* > report-serial.xml

test-serial:
	./tests/bats/bin/bats --filter-tags serial tests/*

# These targets are provided for convenience
# to run just a directory-based subset of tests.

test-include:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/test-config-include.bats

test-jobsub:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/custom_executor_queue/job_submission.bats

test-lifetime:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/custom_executor_queue/lifetime.bats

test-contract:
	./tests/bats/bin/bats tests/contract

test-configure:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/configure/

test-run:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/run/

test-cleanup:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/cleanup/

test-prepare:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/prepare/

test-containerlib:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/containerlib.bats

test-script-wrapper:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/script-enroot-wrapper.bats


test-mocks:
	./tests/bats/bin/bats tests/mocks

test-configure-nomock:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/configure/

test-gitlab-runner-register-wrapper:
	./tests/bats/bin/bats --jobs $(JOBS) -T tests/test-gitlab-runner-register-wrapper.bats

shellcheck-stable/shellcheck:
	bash ./tests/install_shellcheck.sh

shellcheck: shellcheck-stable/shellcheck
	./shellcheck-stable/shellcheck $$(find src -name '*.sh' -or -name '*.slurm') \
               $$(find tests -name '*.bats' \
                  -not -path 'tests/bats/*' \
                  -not -path 'tests/test_helper/*')\
               $$(find tests -name '*.bash' \
                  -not -path 'tests/bats/*' \
                  -not -path 'tests/test_helper/*')\
               $$(find tests -name '*.sh' \
                  -not -path 'tests/bats/*' \
                  -not -path 'tests/test_helper/*')\
               $$(find tests/mocks/bin/ -type f -not -name '*.py')


# This might be useful because for some reason bats process 
# tend to linger around even if the tests are over. 
# This might be due to a poor use of the library
joker: # Batman's nemesis - kills all the bats
	ps aux | grep 'tests/bats/libexec' | grep -v grep | awk '{print $$2}' | xargs kill
