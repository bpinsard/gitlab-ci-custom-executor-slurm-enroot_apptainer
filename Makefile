

test:
	./tests/bats/bin/bats --jobs 8 $$(ls -d tests/* | grep -v '.*serial$$' )
	./tests/bats/bin/bats tests/*serial

test-report-parallel:
	./tests/bats/bin/bats --jobs 8 --formatter junit $$(ls -d tests/* | grep -v '.*serial$$' ) > report-parallel.xml

test-report-serial:
	./tests/bats/bin/bats --formatter junit tests/*serial > report-serial.xml

test-include:
	./tests/bats/bin/bats --jobs 8 -T tests/test-config-include.bats

test-jobsub:
	./tests/bats/bin/bats --jobs 8 -T tests/custom_executor_queue/job_submission.bats

test-lifetime:
	./tests/bats/bin/bats --jobs 8 -T tests/custom_executor_queue/lifetime.bats

test-integration:
	./tests/bats/bin/bats tests/integration

test-configure:
	./tests/bats/bin/bats --jobs 8 -T tests/configure/

test-run:
	./tests/bats/bin/bats --jobs 8 -T tests/run/

test-cleanup:
	./tests/bats/bin/bats --jobs 8 -T tests/cleanup/


test-mocks:
	./tests/bats/bin/bats tests/mocks

# These tests fail when run in parallel
# (pyxis fails with permission denied errors:
# slurmstepd: error: pyxis: child 3977009 failed with error code: 1
# slurmstepd: error: pyxis: failed to create container filesystem
# slurmstepd: error: pyxis: printing enroot log file:
# slurmstepd: error: pyxis:     mkdir: cannot create directory ‘/run/user/248691’: Permission denied
# slurmstepd: error: pyxis: couldn't start container
test-configure-nomock:
	./tests/bats/bin/bats --jobs 8 -T tests/configure/

shellcheck:
	shellcheck $$(find src -name '*.sh') $$(find tests -name '*.bats' -not -path 'tests/bats/*' -not -path 'tests/test_helper/*')

# This might be useful because for some reason bats process 
# tend to linger around even if the tests are over. 
# This might be due to a poor use of the library
joker: # Batman's nemesis - kills all the bats
	ps aux | grep 'tests/bats/libexec' | grep -v grep | awk '{print $$2}' | xargs kill
