# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>
# Lorenzo Leone <lleone@iis.ee.ethz.ch>


CHIM_ROOT ?= $(shell pwd)

# Tooling
BENDER                 ?= bender -d $(CHIM_ROOT)
VERIBLE_VERILOG_FORMAT ?= $(CHIM_UTILS_DIR)/verible-verilog/verible-verilog-format

# Set dependency paths only if dependencies have already been cloned
# This avoids running `bender checkout` at every make command
ifeq ($(shell test -d $(CHIM_ROOT)/.bender || echo 1),)
CHS_ROOT    ?= $(shell $(BENDER) path cheshire)
SN_ROOT 		?= $(shell $(BENDER) path snitch_cluster)
IDMA_ROOT   ?= $(shell $(BENDER) path idma)
HYPERB_ROOT ?= $(shell $(BENDER) path hyperbus)
endif

# Fall back to safe defaults if dependencies are not cloned yet
CHS_ROOT    ?= .
SN_ROOT ?= .
IDMA_ROOT   ?= .
HYPERB_ROOT ?= .

# Chimera's Snitch-cluster HW config (cfg/chimera.json) reproduces the parameters
# currently hand-coded in hw/clusters/chimera_cluster.sv. It drives generation of
# snitch_cluster_pkg.sv + snitch_cluster_wrapper.sv (`make sn-hw-all`), so the
# cluster config lives in one place instead of being duplicated in RTL.
SN_CFG = $(CHIM_ROOT)/cfg/chimera.json

# Bender prerequisites
BENDER_YML = $(CHIM_ROOT)/Bender.yml
BENDER_LOCK = $(CHIM_ROOT)/Bender.lock

CHS_XLEN ?= 64

CHIM_HW_DIR ?= $(CHIM_ROOT)/hw
CHIM_SW_DIR ?= $(CHIM_ROOT)/sw

-include $(CHS_ROOT)/cheshire.mk
-include $(CHIM_ROOT)/chimera.mk
-include $(CHIM_ROOT)/rdl.mk

########
# MISC #
########
UV ?= uv
# Keep the uv cache on the (writable, large) repo scratch, not $HOME (small IIS quota).
export UV_CACHE_DIR ?= $(CHIM_ROOT)/.cache/uv

.PHONY: dvt-flist python-venv python-venv-clean

dvt_flist:
	mkdir -p .dvt
	$(BENDER) script flist-plus $(COMMON_TARGS) $(SIM_TARGS) > .dvt/default.build

python-venv: .venv ## Create the Python virtual environment (uv)
.venv:
	$(UV) sync

python-venv-clean: ## Clean Python virtual environment
	rm -rf .venv

#################
# Documentation #
#################

.PHONY: help h

Black=\033[0m
Green=\033[1;32m
help h: ## Show an overview of all Makefile targets.
	@echo -e "Makefile ${Green}targets${Black} for chimera"
	@echo -e "Use 'make <target>' where <target> is one of:"
	@echo -e ""
	@awk -v green="$(Green)" -v black="$(Black)" ' \
		BEGIN { FS = ":.*?## "; section = "" } \
		/^##@/ { section = substr($$0, 5); printf "\033[1m%s:\033[0m\n", section; next } \
		/^[a-zA-Z0-9._-]+:.*##/ { \
			printf "  " green "%-20s" black " %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)
