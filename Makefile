.DEFAULT_GOAL := help

SHELL=/bin/bash
VENV = venv

# Detect the operating system and set the virtualenv bin directory
ifeq ($(OS),Windows_NT)
	VENV_BIN=$(VENV)\Scripts
else
	VENV_BIN=$(VENV)/bin
endif

setup: $(VENV)/bin/activate

$(VENV)/bin/activate: $(VENV)/.venv-timestamp

$(VENV)/.venv-timestamp: setup.py requirements
# Create new virtual environment if setup.py has changed
	python -m venv $(VENV)
	$(VENV_BIN)\python.exe -m pip install --upgrade pip
	$(VENV_BIN)\python.exe -m pip install -r requirements/dev-requirements.txt
	$(VENV_BIN)\python.exe -m pip install -r requirements/lint-requirements.txt
# 使用echo命令来创建或更新时间戳文件
	echo "" > $(VENV)/.venv-timestamp

testenv: $(VENV)/.testenv

$(VENV)/.testenv: $(VENV)/bin/activate
# $(VENV_BIN)\python.exe -m pip install -e ".[framework]"
# the openai optional dependency is include framework and rag dependencies
	$(VENV_BIN)\python.exe -m pip install -e ".[openai]"
# 使用echo命令来创建或更新时间戳文件
	echo "" > $(VENV)/.testenv

.PHONY: fmt
fmt: setup ## Format Python code
# TODO: Use isort to sort Python imports.
# https://github.com/PyCQA/isort
# $(VENV_BIN)/isort.exe .
	$(VENV_BIN)\isort.exe dbgpt/
	$(VENV_BIN)\isort.exe --extend-skip="examples/notebook" examples
# https://github.com/psf/black
	$(VENV_BIN)\black.exe --extend-exclude="examples/notebook" .
# TODO: Use blackdoc to format Python doctests.
# https://blackdoc.readthedocs.io/en/latest/
# $(VENV_BIN)/blackdoc.exe .
	$(VENV_BIN)\blackdoc.exe dbgpt
	$(VENV_BIN)\blackdoc.exe examples
# TODO: Use flake8 to enforce Python style guide.
# https://flake8.pycqa.org/en/latest/
	$(VENV_BIN)\flake8.exe dbgpt/core/ dbgpt/rag/ dbgpt/storage/ dbgpt/datasource/ dbgpt/client/ dbgpt/agent/ dbgpt/vis/ dbgpt/experimental/
# TODO: More package checks with flake8.

.PHONY: fmt-check
fmt-check: setup ## Check Python code formatting and style without making changes
	$(VENV_BIN)\isort.exe --check-only dbgpt/
	$(VENV_BIN)\isort.exe --check-only --extend-skip="examples/notebook" examples
	$(VENV_BIN)\black.exe --check --extend-exclude="examples/notebook" .
	$(VENV_BIN)\blackdoc.exe --check dbgpt examples
	$(VENV_BIN)\flake8.exe dbgpt/core/ dbgpt/rag/ dbgpt/storage/ dbgpt/datasource/ dbgpt/client/ dbgpt/agent/ dbgpt/vis/ dbgpt/experimental/

.PHONY: pre-commit
pre-commit: fmt-check test test-doc mypy ## Run formatting and unit tests before committing

test: $(VENV)/.testenv ## Run unit tests
	$(VENV_BIN)/pytest dbgpt

.PHONY: test-doc
test-doc: $(VENV)/.testenv ## Run doctests
# -k "not test_" skips tests that are not doctests.
	$(VENV_BIN)/pytest --doctest-modules -k "not test_" dbgpt/core

.PHONY: mypy
mypy: $(VENV)/.testenv ## Run mypy checks
# https://github.com/python/mypy
	$(VENV_BIN)/mypy --config-file .mypy.ini dbgpt/rag/ dbgpt/datasource/ dbgpt/client/ dbgpt/agent/ dbgpt/vis/ dbgpt/experimental/
# rag depends on core and storage, so we not need to check it again.
# $(VENV_BIN)/mypy --config-file .mypy.ini dbgpt/storage/
# $(VENV_BIN)/mypy --config-file .mypy.ini dbgpt/core/
# TODO: More package checks with mypy.

.PHONY: coverage
coverage: setup ## Run tests and report coverage
	$(VENV_BIN)/pytest dbgpt --cov=dbgpt

.PHONY: clean
clean: ## Clean up the environment
	rm -rf $(VENV)
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -delete
	find . -type d -name '.pytest_cache' -delete
	find . -type d -name '.coverage' -delete

.PHONY: clean-dist
clean-dist: ## Clean up the distribution
	rm -rf dist/ *.egg-info build/

.PHONY: package
package: clean-dist ## Package the project for distribution
	IS_DEV_MODE=false python setup.py sdist bdist_wheel

.PHONY: upload
upload: ## Upload the package to PyPI
# upload to testpypi: twine upload --repository testpypi dist/*
	twine upload dist/*

.PHONY: help
help:  ## Display this help screen
	@echo "Available commands:"
	@grep -E '^[a-z.A-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' | sort