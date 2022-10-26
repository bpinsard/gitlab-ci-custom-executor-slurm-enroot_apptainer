

test:
	./tests/bats/bin/bats tests/

test-jobsub:
	./tests/bats/bin/bats tests/allocation_manager_job_submission.bats

test-joblife:
	./tests/bats/bin/bats tests/allocation_manager_lifetime.bats
