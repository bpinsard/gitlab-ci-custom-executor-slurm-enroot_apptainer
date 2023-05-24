SCRIPTS_SRC_RWX  := src/configure-slurm.sh                                   \
                    src/prepare.sh                                           \
                    src/run.sh                                               \
                    src/cleanup-slurm.sh
SCRIPTS_SRC_RW   := src/configure-slurm-include.sh                           \
                    src/cleanup-slurm-include.sh                             \
                    src/cleanup-singularity.sh                               \
                    src/cleanup-enroot.sh                                    \
                    src/custom_executor_queue.sh                             \
                    src/containerlib-enroot.sh                               \
                    src/containerlib-singularity.sh                          \
                    src/include.sh                                           \
                    src/job.slurm.template                                   \
                    src/prepare-enroot.sh                                    \
                    src/prepare-singularity.sh                               \
                    src/run-include.sh                                       \
                    src/script-enroot-wrapper.sh                             \
                    src/script-singularity-wrapper.sh                        \
                    src/slurm-utils/get-sbatch-input-env-list.sh             \
                    src/slurm-utils/_get-sbatch-input-env-list.sh
SCRIPTS_UTILS_RWX := utils/gitlab-runner-register-wrapper.sh
DOC               := README.md
MAKEFILE          := packaging/Makefile
SPECFILE          := packaging/gitlab-custom-executor-singularity-enroot.spec
VERSION           := v1.0
PREFIX            := /usr/share/gitlab-runner/custom-executor-slurm-singularity-enroot
DATA_DIR          := $(DESTDIR)$(PREFIX)

.PHONY: install
install: $(SCRIPTS_SRC_RWX) $(SCRIPTS_SRC_RW) $(SCRIPTS_UTILS_RWX) $(Makefile)
	install --directory --verbose "$(DATA_DIR)/"
	install --directory --verbose "$(DATA_DIR)/src"
	install --directory --verbose "$(DATA_DIR)/utils"
	install --mode=u=rwx,go=rx --verbose --target-directory="$(DATA_DIR)/src"  \
	         $(SCRIPTS_SRC_RWX)
	install --mode=u=rw,go=r   --verbose --target-directory="$(DATA_DIR)/src"  \
	         $(SCRIPTS_SRC_RW)
	install --mode=u=rwx,go=rx --verbose --target-directory="$(DATA_DIR)/utils"\
	         $(SCRIPTS_UTILS_RWX)
	install --mode=u=rw,go=r   --verbose --target-directory="$(DATA_DIR)"      \
	         $(DOC)
	sed -i -e "s@<PREFIX>@$(PREFIX)@g" -e "s@<VERSION>@$(VERSION)@" "$(DATA_DIR)/$(DOC)"

.INTERMEDIATE: rpmbuild.tar
rpmbuild.tar: $(SCRIPTS_SRC_RWX) $(SCRIPTS_SRC_RW) $(SCRIPTS_UTILS_RWX) $(DOC) $(MAKEFILE) $(SPECFILE)
	tar --create --verbose --transform='s@^@gitlab-custom-executor-slurm-singularity-enroot/@g' --file="$@" $^

.PHONY: rpm
rpm: rpmbuild.tar
	rpmbuild -tb $^
