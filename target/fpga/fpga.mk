# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Sergio Mazzola <smazzola@iis.ee.ethz.ch>

ifndef chim_fpga_mk
chim_fpga_mk=1

CHIM_FPGA_DIR ?= $(CHIM_ROOT)/target/fpga

VIVADO ?= vitis-2022.1 vivado

.PHONY: chim-fpga-padframe

chim-fpga-padframe: $(CHIM_FPGA_DIR)/src/padframe/chimera_padframe_ip

$(CHIM_FPGA_DIR)/src/padframe/chimera_padframe_ip: $(CHIM_FPGA_DIR)/src/padframe/chimera_padframe.yml $(CHIM_UTILS_DIR)/solderpad_header.txt
	mkdir -p $(CHIM_FPGA_DIR)/src/padframe
	cd $(CHIM_FPGA_DIR)/src/padframe && $(PADRICK) generate rtl chimera_padframe.yml -o $@ --header $(CHIM_UTILS_DIR)/solderpad_header.txt --no-version-string

endif # chim_fpga_mk
