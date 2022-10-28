

test:
	./tests/bats/bin/bats tests/*

test-jobsub:
	./tests/bats/bin/bats tests/allocation_manager/job_submission.bats

test-lifetime:
	./tests/bats/bin/bats tests/allocation_manager/lifetime.bats

shellcheck:
	shellcheck ./src/* ./tests/*.sh
