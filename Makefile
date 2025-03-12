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
PULP_ROOT   ?= $(shell $(BENDER) path pulp_cluster)
IDMA_ROOT   ?= $(shell $(BENDER) path idma)
HYPERB_ROOT ?= $(shell $(BENDER) path hyperbus)
endif

# Fall back to safe defaults if dependencies are not cloned yet
CHS_ROOT    ?= .
SNITCH_ROOT ?= .
PULP_ROOT   ?= .
IDMA_ROOT   ?= .
HYPERB_ROOT ?= .

CHS_XLEN ?= 32

CHIM_HW_DIR ?= $(CHIM_ROOT)/hw
CHIM_SW_DIR ?= $(CHIM_ROOT)/sw

-include $(CHS_ROOT)/cheshire.mk
-include $(CHIM_ROOT)/chimera.mk
