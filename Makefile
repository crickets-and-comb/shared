PYTHON_VERSION ?= 3.12
PACKAGE_NAME ?= $(shell python -c "import configparser; cfg = configparser.ConfigParser(); cfg.read('setup.cfg'); print(cfg['metadata']['name'])")
CONDA_ENV_NAME ?= ${PACKAGE_NAME}_py${PYTHON_VERSION}
REPO_ROOT ?= $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
QC_DIRS ?= ${REPO_ROOT}src/ ${REPO_ROOT}tests/ ${REPO_ROOT}docs/
INSTALL_EXTRAS ?= [dev] # [build] [dev] [qc] [test] [doc]

CHECKOUT_SHARED ?= $(shell grep CHECKOUT_SHARED .env | cut -d '=' -f2)
ORG_READ_TOKEN ?= $(shell grep ORG_READ_TOKEN .env | cut -d '=' -f2)
SAFETY_API_KEY ?= $(shell grep SAFETY_API_KEY .env | cut -d '=' -f2) # Your safety API key. For local dev, you can simply add SAFETY_API_KEY to your environment via a .env file or explicit export.
SAFETY_KEY_FLAG = $(if $(SAFETY_API_KEY),--key $(SAFETY_API_KEY),)

DOC_BUILD_DIR ?= docs/_build/
DIST_DIR ?= dist/

ACT_RUN_EVENT ?= workflow_dispatch
CI_CD_FILE_NAME ?= CI_CD.yml
MATRIX_OS ?= ubuntu-latest
MATRIX_PYTHON_VERSION ?=
TEST_OR_PROD ?= dev


# Security opt-ins:
RUN_BANDIT ?= 1
RUN_SAFETY ?= 1
RUN_PIP_AUDIT ?= 1

# Temporary workaround to skip pytype on Python 3.13+ until pytype is replaced. See https://github.com/crickets-and-comb/shared/issues/99
ifeq ($(PYTHON_VERSION),3.12)
RUN_PYTYPE ?= 1
else
RUN_PYTYPE ?= 0
endif

RUN_BASEDPYRIGHT ?= 0

EXCLUDED_TARGETS_FROM_LIST ?= # Just excludes from list-makes. Doesn't remove from available targets.
.DEFAULT_GOAL = list-makes
.PHONY: build-doc build-env build-package clean delete-all-branches delete-local-branch delete-remote-branch e2e format full full-qc full-test install integration lint list-makes remove-env run-act security typecheck unit update-shared

list-makes: # Print make targets, optionally excluding certain ones.
	for file in $(MAKEFILE_LIST); do \
		echo "Makefile targets from $$file:"; \
		grep -i "^[a-zA-Z][a-zA-Z0-9_ \.\-]*: .*[#].*" $$file | sort | sed 's/:.*#/ : /g' | { \
			if [ -n "$(EXCLUDED_TARGETS_FROM_LIST)" ]; then grep -vE "($(EXCLUDED_TARGETS_FROM_LIST))"; else cat; fi; \
		} | column -t -s:; \
		echo ""; \
	done

build-env: # Build the dev env. You may want to add other extras here like mysqlclient etc. This does not install the package under development.
	conda create -n ${CONDA_ENV_NAME} python=${PYTHON_VERSION} --yes

install: # Install this package in local editable mode.
	python -m pip install --upgrade pip setuptools
	python -m pip install -e ${REPO_ROOT}${INSTALL_EXTRAS}

full: # Run a "full" install, QC, test, and build. You'll need to have the environment already activated even though it rebuilds it.
	$(MAKE) build-env install INSTALL_EXTRAS=[dev] full-qc full-test build-doc build-package

full-qc: # Run all the QC.
	$(MAKE) lint security typecheck

full-test: # Run all the tests.
	$(MAKE) unit integration e2e

clean: # Clear caches and coverage reports, etc.
	cd ${REPO_ROOT} && rm -rf dist .coverage* cov_report* .pytest_cache .pytype src/${PACKAGE_NAME}.egg-info *_test_report.xml
	$(shell find ${REPO_ROOT} -type f -name '*py[co]' -delete -o -type d -name __pycache__ -delete)

format: # Clean up code.
	black --config ${REPO_ROOT}shared/pyproject.toml ${QC_DIRS}
	isort -p ${PACKAGE_NAME} --settings-path ${REPO_ROOT}shared/pyproject.toml ${QC_DIRS}

lint: # Check style and formatting. Should agree with format and only catch what format can't fix, like line length, missing docstrings, etc.
	black --config ${REPO_ROOT}shared/pyproject.toml --check ${QC_DIRS}
	isort -p ${PACKAGE_NAME} --settings-path ${REPO_ROOT}shared/pyproject.toml --check-only ${QC_DIRS}
	flake8 --config ${REPO_ROOT}shared/.flake8 ${QC_DIRS}

security: # Check for vulnerabilities.
	if [ "$(RUN_BANDIT)" = "1" ]; then \
		echo "Running bandit..."; \
		bandit -r ${REPO_ROOT}src; \
	else \
		echo "Skipping bandit."; \
	fi

	if [ "$(RUN_SAFETY)" = "1" ]; then \
		echo "Running safety..."; \
		safety ${SAFETY_KEY_FLAG} scan; \
		safety ${SAFETY_KEY_FLAG} scan --target shared; \
	else \
		echo "Skipping safety."; \
	fi

# CVE-2018-20225: Ignoring as the use of --extra-index-url is secure in pip install in workflows/install_package.yaml.
# CVE-2024-9880: This can be avoided by validating user input passed to pandas.DataFrame.query.
# CVE-2024-34997: CWE-502: Deserialization of Untrusted Data. Disputed by supplier. Not a vulnerability in Python 3.13.
# CVE-2025-71176: CWE-379: Creation of Temporary File in Directory with Incorrect Permissions: pytest through 9.0.2 on UNIX relies on directories with the /tmp/pytest-of-{user} name pattern, which allows local users to cause a denial of service or possibly gain privileges.
# TODO: Drop CVE-2024-34997 from pip-audit ignore list when dropping Python 3.12 support. https://github.com/crickets-and-comb/shared/issues/34
	if [ "$(RUN_PIP_AUDIT)" = "1" ]; then \
		echo "Running pip-audit..."; \
		pip-audit --ignore-vuln CVE-2018-20225 --ignore-vuln CVE-2024-9880 --ignore-vuln CVE-2024-34997 --ignore-vuln CVE-2025-71176; \
	else \
		echo "Skipping pip-audit."; \
	fi

# TODO: Phase out pytype in favor of mypy or another typechecker that supports Python 3.13+.
# https://github.com/crickets-and-comb/shared/issues/99
typecheck: # Check typing (runs only if pytype is installed).
	if [ "$(RUN_PYTYPE)" = "1" ]; then \
		pytype --config="${REPO_ROOT}shared/pytype.cfg" -- ${QC_DIRS}; \
	else \
		echo "Skipping pytype."; \
	fi

	if [ "$(RUN_BASEDPYRIGHT)" = "1" ]; then \
		if command -v basedpyright >/dev/null 2>&1; then \
			echo "Running basedpyright..."; \
			basedpyright ${QC_DIRS}; \
		else \
			echo "Error: basedpyright is not installed but RUN_BASEDPYRIGHT=1"; \
			exit 1; \
		fi; \
	else \
		echo "Skipping basedpyright."; \
	fi

run-test: # Base call to pytest. (Export MARKER to specify the test type.)
	pytest -m ${MARKER} ${REPO_ROOT} --rootdir ${REPO_ROOT} -c ${REPO_ROOT}pyproject.toml

unit: # Run unit tests.
	$(MAKE) run-test MARKER=unit

integration: #Run integration tests.
	$(MAKE) run-test MARKER=integration

e2e: # Run end-to-end tests.
	$(MAKE) run-test MARKER=e2e

build-doc: # Build Sphinx docs, from autogenerated API docs and human-written RST files.
	if [ -d "${REPO_ROOT}${DOC_BUILD_DIR}" ]; then rm -r ${REPO_ROOT}${DOC_BUILD_DIR}; fi
	mkdir ${REPO_ROOT}${DOC_BUILD_DIR}
	sphinx-apidoc -o ${REPO_ROOT}docs ${REPO_ROOT}src/${PACKAGE_NAME} -f
	sphinx-build ${REPO_ROOT}docs ${REPO_ROOT}${DOC_BUILD_DIR}

build-package: # Build the package to deploy.
	rm -rf ${REPO_ROOT}${DIST_DIR}
	python -m build ${REPO_ROOT}
	twine check ${DIST_DIR}/*

set-CI-CD-file: # Override to update the CI-CD file for run-act, e.g. to use local shared workflows instead of via GitHub URLs.
	echo "No changes made to CI-CD file."
	# e.g.
	# perl -pi -e 's|crickets-and-comb/shared/.github/workflows/CI\.yml\@main|./shared/.github/workflows/CI.yml|g' .github/workflows/CI_CD_act.yml

run-act: # Run the CI-CD workflow.
	$(eval MATRIX_OS_FLAG := $(if $(MATRIX_OS),--matrix os:${MATRIX_OS},))
	$(eval MATRIX_PYTHON_VERSION_FLAG := $(if $(MATRIX_PYTHON_VERSION),--matrix python-version:${MATRIX_PYTHON_VERSION},))
	$(eval PYTHON_BUILD_VERSION := $(if $(MATRIX_PYTHON_VERSION),${MATRIX_PYTHON_VERSION},${PYTHON_VERSION}))

	cp .github/workflows/${CI_CD_FILE_NAME} .github/workflows/CI_CD_act.yml
	$(MAKE) set-CI-CD-file

	act ${ACT_RUN_EVENT} -W .github/workflows/CI_CD_act.yml --defaultbranch main ${MATRIX_OS_FLAG} ${MATRIX_PYTHON_VERSION_FLAG} \
		-s CHECKOUT_SHARED=${CHECKOUT_SHARED} -s ORG_READ_TOKEN=${ORG_READ_TOKEN} -s SAFETY_API_KEY=${SAFETY_API_KEY} \
		--input TEST_OR_PROD=${TEST_OR_PROD} --input PYTHON_BUILD_VERSION=${PYTHON_BUILD_VERSION}