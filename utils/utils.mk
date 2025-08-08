# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Sergio Mazzola <smazzola@iis.ee.ethz.ch>

ifndef chim_utils_mk
chim_utils_mk=1

CHIM_UTILS_DIR ?= $(CHIM_ROOT)/utils

# Verilog formatting
FORMAT_VERILOG_SRC = $(wildcard \
	hw/*.sv \
	target/sim/src/*.sv \
	target/fpga/src/chimera/*.sv \
)

# Checks if verible-verilog-format is installed, otherwise it looks for a Makefile target in our flow to install it
format-verilog: $(shell if ! `which $(VERIBLE_VERILOG_FORMAT) 2> /dev/null`; then echo $(VERIBLE_VERILOG_FORMAT); fi)
	$(VERIBLE_VERILOG_FORMAT) --flagfile .verilog_format --inplace --verbose $(FORMAT_VERILOG_SRC)

# Download verible-verilog-format
$(CHIM_UTILS_DIR)/verible-verilog/verible-verilog-format:
	mkdir -p $(CHIM_UTILS_DIR)/verible-verilog
	cd $(CHIM_UTILS_DIR)/verible-verilog && curl https://api.github.com/repos/chipsalliance/verible/releases/tags/v0.0-3752-g8b64887e \
	| grep "browser_download_url.*verible-v0.0-3752-g8b64887e-linux-static-x86_64.tar.gz" \
	| cut -d : -f 2,3 \
	| tr -d \" \
	| wget -qi -
	tar -xvzf $(CHIM_UTILS_DIR)/verible-verilog/verible-v0.0-3752-g8b64887e-linux-static-x86_64.tar.gz -C $(CHIM_UTILS_DIR)/verible-verilog
	chmod a+x $(CHIM_UTILS_DIR)/verible-verilog/verible-v0.0-3752-g8b64887e/bin/*
	mv $(CHIM_UTILS_DIR)/verible-verilog/verible-v0.0-3752-g8b64887e/bin/* $(CHIM_UTILS_DIR)/verible-verilog
	rm -rf $(CHIM_UTILS_DIR)/verible-verilog/verible-v0.0-3752-g8b64887e*

# Clean up
.PHONY: utils-clean
utils-clean:
	@rm -rf $(CHIM_UTILS_DIR)/verible-verilog

endif # chim_utils_mk
