

test:
	./tests/bats/bin/bats --jobs 4 -T tests/*

test-jobsub:
	./tests/bats/bin/bats --jobs 4 -T tests/allocation_manager/job_submission.bats

test-lifetime:
	./tests/bats/bin/bats --jobs 4 -T tests/allocation_manager/lifetime.bats


test-integration:
	./tests/bats/bin/bats tests/integration


test-mocks:
	./tests/bats/bin/bats tests/mocks

shellcheck:
	shellcheck ./src/*
