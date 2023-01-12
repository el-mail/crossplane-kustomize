# Project Setup
PROJECT_NAME := crossplane-kustomize # TODO: rename to crossplane-blueprints
PROJECT_REPO := https://github.com/el-mail/$(PROJECT_NAME)

PLATFORMS ?= linux_amd64 linux_arm64
include build/makelib/common.mk

# ====================================================================================
# Targets

# run `make help` to see the targets and options

# We want submodules to be set up the first time `make` is run.
# We manage the build/ folder and its Makefiles as a submodule.
# The first time `make` is run, the includes of build/*.mk files will
# all fail, and this target will be run. The next time, the default as defined
# by the includes will be run instead.
fallthrough: submodules
	@echo Initial setup complete. Running make again . . .
	@make

# Update the submodules, such as the common build scripts.
submodules:
	@git submodule sync
	@git submodule update --init --recursive

# ====================================================================================

define HELPTEXT
Usage: make [make-options] <target> [options]

Common Targets:
    gen     Run code generation.
    reviewable   Validate that a PR is ready for review.
endef
export HELPTEXT

%:
ifneq (,$(findstring gen,$(filter gen%,$(MAKECMDGOALS))))
	@:
endif


gen: gen.xrd gen.composition

gen.xrd:
	@$(INFO) Generating XRD
	@$(ROOT_DIR)/scripts/xrd_generator.sh $(filter-out gen%,$(MAKECMDGOALS)) || $(FAIL)

gen.composition:
	@$(INFO) Generating Composition
	@$(ROOT_DIR)/scripts/composition_generator.sh $(filter-out gen%,$(MAKECMDGOALS)) || $(FAIL)

# # create_aws_creds : $(KUBECTL)
# # 	AWS_PROFILE=default && echo -e "[default]\naws_access_key_id = $(aws configure get aws_access_key_id --profile $AWS_PROFILE)\naws_secret_access_key = $(aws configure get aws_secret_access_key --profile $AWS_PROFILE)" > creds.conf
# # 	$(KUBECTL) create secret generic aws-creds -n crossplane-system --from-file=creds=./creds.conf

.PHONY : gen gen.xrd gen.composition
