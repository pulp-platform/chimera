# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>

CHIM_ROOT ?= $(shell pwd)
BENDER    ?= bender -d $(CHIM_ROOT)
PADRICK   ?= padrick

CHS_ROOT    ?= $(shell $(BENDER) path cheshire)
SNITCH_ROOT ?= $(shell $(BENDER) path snitch_cluster)
IDMA_ROOT   ?= $(shell $(BENDER) path idma)

CHS_XLEN ?= 32

CHIM_HW_DIR ?= $(CHIM_ROOT)/hw
CHIM_SW_DIR ?= $(CHIM_ROOT)/sw

-include $(CHS_ROOT)/cheshire.mk
-include $(CHIM_ROOT)/chimera.mk
