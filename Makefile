

test:
	./tests/bats/bin/bats --jobs 4 -T tests/*

test-include:
	./tests/bats/bin/bats --jobs 4 -T tests/test-include.bats

test-jobsub:
	./tests/bats/bin/bats --jobs 4 -T tests/allocation_manager/job_submission.bats

test-lifetime:
	./tests/bats/bin/bats --jobs 4 -T tests/allocation_manager/lifetime.bats

test-integration:
	./tests/bats/bin/bats tests/integration

test-configure:
	./tests/bats/bin/bats tests/configure


test-mocks:
	./tests/bats/bin/bats tests/mocks

shellcheck:
	shellcheck $$(find src -name '*.sh')
