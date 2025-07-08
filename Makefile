# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>

CHIM_ROOT ?= $(shell pwd)

# Tooling
BENDER                 ?= bender -d $(CHIM_ROOT)
VERIBLE_VERILOG_FORMAT ?= $(CHIM_UTILS_DIR)/verible-verilog/verible-verilog-format
PEAKRDL                ?= peakrdl

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

CHS_XLEN ?= 32

CHIM_HW_DIR ?= $(CHIM_ROOT)/hw
CHIM_SW_DIR ?= $(CHIM_ROOT)/sw

-include $(CHS_ROOT)/cheshire.mk
-include $(CHIM_ROOT)/chimera.mk

#################
# Documentation #
#################

.PHONY: help

Black=\033[0m
Green=\033[1;32m
help:
	@echo -e "Makefile ${Green}targets${Black} for chimera"
	@echo -e "Use 'make <target>' where <target> is one of:"
	@echo -e ""
	@echo -e "${Green}help           	     ${Black}Show an overview of all Makefile targets."
	@echo -e ""
	@echo -e "General targets:"
	@echo -e "${Green}chim-all             ${Black}Generate entire chimera infrastructure."
	@echo -e "${Green}chim-clean           ${Black}Clean entire chimera infrastructure."
	@echo -e ""
	@echo -e "Source generation targets:"
	@echo -e "${Green}chim-sim             ${Black}Generate Chimera simulation files"
	@echo -e "${Green}chim-bootrom-init    ${Black}Generate SoC bootrom"
	@echo -e "${Green}regenerate_soc_regs  ${Black}Generate SoC configuration registers"
	@echo -e "${Green}snitch-hw-init       ${Black}Generate Snitch RTL"
	@echo -e "${Green}snitch_bootrom       ${Black}Generate Snitch bootrom"
	@echo -e "${Green}chs-hw-init          ${Black}Generate Cheshire RTL"
	@echo -e "${Green}chs-sim-all          ${Black}Generate Cheshire simulation files"
	@echo -e ""
	@echo -e "Software:"
	@echo -e "${Green}chim-sw             ${Black}Compile all software tests"
	@echo -e "${Green}chimera-addrmap     ${Black}Regenerate c-header for SoC address map"
	@echo -e ""
