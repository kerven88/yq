MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -euc
.DEFAULT_GOAL := install

include Makefile.variables

.PHONY: help
help:
	@echo 'Management commands for cicdtest:'
	@echo
	@echo 'Usage:'
	@echo '  ## Develop / Test Commands'
	@echo '    make build           Build yq binary.'
	@echo '    make install         Install yq.'
	@echo '    make xcompile        Build cross-compiled binaries of yq.'
	@echo '    make vendor          Install dependencies to vendor directory.'
	@echo '    make format          Run code formatter.'
	@echo '    make check           Run static code analysis (lint).'
	@echo '    make secure          Run gosec.'
	@echo '    make test            Run tests on project.'
	@echo '    make cover           Run tests and capture code coverage metrics on project.'
	@echo '    make clean           Clean the directory tree of produced artifacts.'
	@echo
	@echo '  ## Utility Commands'
	@echo '    make setup           Configures Minishfit/Docker directory mounts.'
	@echo


.PHONY: clean
clean:
	@rm -rf bin build cover *.out

## prefix before other make targets to run in your local dev environment
local: | quiet
	@$(eval DOCKRUN= )
	@mkdir -p tmp
	@touch tmp/dev_image_id
quiet: # this is silly but shuts up 'Nothing to be done for `local`'
	@:

prepare: tmp/dev_image_id
tmp/dev_image_id: Dockerfile.dev scripts/devtools.sh
	@mkdir -p tmp
	@docker rmi -f ${DEV_IMAGE} > /dev/null 2>&1 || true
	@docker build -t ${DEV_IMAGE} -f Dockerfile.dev .
	@docker inspect -f "{{ .ID }}" ${DEV_IMAGE} > tmp/dev_image_id

# ----------------------------------------------
# build
.PHONY: build
build: build/dev

.PHONY: build/dev
build/dev: test *.go
	@mkdir -p bin/
	${DOCKRUN} go build --ldflags "$(LDFLAGS)"
	${DOCKRUN} bash ./scripts/acceptance.sh

## Compile the project for multiple OS and Architectures.
xcompile: check
	@rm -rf build/
	@mkdir -p build
	${DOCKRUN} bash ./scripts/xcompile.sh
	@find build -type d -exec chmod 755 {} \; || :
	@find build -type f -exec chmod 755 {} \; || :

.PHONY: install
install: build
	${DOCKRUN} go install

# Each of the fetch should be an entry within vendor.json; not currently included within project
.PHONY: vendor
vendor: tmp/dev_image_id
	${DOCKRUN} go mod vendor

# ----------------------------------------------
# develop and test

.PHONY: format
format: vendor
	${DOCKRUN} bash ./scripts/format.sh


.PHONY: secure
secure: format
	${DOCKRUN} bash ./scripts/secure.sh

.PHONY: check
check: secure
	${DOCKRUN} bash ./scripts/check.sh



.PHONY: test
test: check
	${DOCKRUN} bash ./scripts/test.sh

.PHONY: cover
cover: check
	@rm -rf cover/
	@mkdir -p cover
	${DOCKRUN} bash ./scripts/coverage.sh
	@find cover -type d -exec chmod 755 {} \; || :
	@find cover -type f -exec chmod 644 {} \; || :


.PHONY: release
release: xcompile
	${DOCKRUN} bash ./scripts/publish.sh

# ----------------------------------------------
# utilities

.PHONY: setup
setup:
	@bash ./scripts/setup.sh
