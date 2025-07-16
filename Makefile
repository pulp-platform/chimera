# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>

CHIM_ROOT ?= $(shell pwd)

# Tooling
BENDER                 ?= bender -d $(CHIM_ROOT)
VERIBLE_VERILOG_FORMAT ?= $(CHIM_UTILS_DIR)/verible-verilog/verible-verilog-format

# Set dependency paths only if dependencies have already been cloned
# This avoids running `bender checkout` at every make command
ifeq ($(shell test -d $(CHIM_ROOT)/.bender || echo 1),)
CHS_ROOT    ?= $(shell $(BENDER) path cheshire)
SNITCH_ROOT ?= $(shell $(BENDER) path snitch_cluster)
IDMA_ROOT   ?= $(shell $(BENDER) path idma)
HYPERB_ROOT ?= $(shell $(BENDER) path hyperbus)
endif

# Fall back to safe defaults if dependencies are not cloned yet
CHS_ROOT    ?= .
SNITCH_ROOT ?= .
IDMA_ROOT   ?= .
HYPERB_ROOT ?= .

# Bender prerequisites
BENDER_YML = $(CHIM_ROOT)/Bender.yml
BENDER_LOCK = $(CHIM_ROOT)/Bender.lock

CHS_XLEN ?= 32

CHIM_HW_DIR ?= $(CHIM_ROOT)/hw
CHIM_SW_DIR ?= $(CHIM_ROOT)/sw

-include $(CHS_ROOT)/cheshire.mk
-include $(CHIM_ROOT)/chimera.mk

########
# MISC #
########
BASE_PYTHON ?= python
PIP_CACHE_DIR ?= $(CHIM_ROOT)/.cache/pip

.PHONY: dvt-flist pythomn-venv python-venv-clean

dvt_flist:
	mkdir -p .dvt
	$(BENDER) script flist-plus $(COMMON_TARGS) $(SIM_TARGS) > .dvt/default.build

python-venv: .venv
.venv:
	$(BASE_PYTHON) -m venv $@
	. $@/bin/activate && \
	python -m pip install --upgrade pip setuptools && \
	python -m pip install --cache-dir $(PIP_CACHE_DIR) -r requirements.txt

#################
# Documentation #
#################

.PHONY: help

Black=\033[0m
Green=\033[1;32m
help: ## Show an overview of all Makefile targets.
	@echo -e "Makefile ${Green}targets${Black} for chimera"
	@echo -e "Use 'make <target>' where <target> is one of:"
	@echo -e ""
	@awk -v green="$(Green)" -v black="$(Black)" ' \
		BEGIN { FS = ":.*?## "; section = "" } \
		/^##@/ { section = substr($$0, 5); printf "\033[1m%s:\033[0m\n", section; next } \
		/^[a-zA-Z0-9._-]+:.*##/ { \
			printf "  " green "%-20s" black " %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)