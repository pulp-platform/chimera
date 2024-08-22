# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Sergio Mazzola <smazzola@iis.ee.ethz.ch>

ifndef chim_utils_mk
chim_utils_mk=1

CHIM_UTILS_DIR ?= $(CHIM_ROOT)/utils

# Function to download and install binaries from GitHub releases
define download_git_bin
	cd $(1) && curl https://api.github.com/repos/$(2)/releases/tags/$(3) \
	| grep "browser_download_url.*$(4)" \
	| cut -d : -f 2,3 \
	| tr -d \" \
	| wget -qi -
endef

.PHONY: chim-format-verilog chim-utils-clean

# Verilog formatting
FORMAT_VERILOG_SRC = $(wildcard \
	hw/*.sv \
	target/sim/src/*.sv \
	target/fpga/src/chimera/*.sv \
)

# Checks if verible-verilog-format is installed, otherwise it looks for a Makefile target in our flow to install it
chim-format-verilog: $(VERIBLE_VERILOG_FORMAT)
	$(VERIBLE_VERILOG_FORMAT) --flagfile .verilog_format --inplace --verbose $(FORMAT_VERILOG_SRC)

# Download verible-verilog-format binaries (only x86_64)
$(CHIM_UTILS_DIR)/verible-verilog/verible-verilog-format:
	mkdir -p $(CHIM_UTILS_DIR)/verible-verilog
	$(call download_git_bin,$(CHIM_UTILS_DIR)/verible-verilog,chipsalliance/verible,v0.0-3752-g8b64887e,verible-v0.0-3752-g8b64887e-linux-static-x86_64.tar.gz)
	tar -xvzf $(CHIM_UTILS_DIR)/verible-verilog/verible-v0.0-3752-g8b64887e-linux-static-x86_64.tar.gz -C $(CHIM_UTILS_DIR)/verible-verilog
	chmod a+x $(CHIM_UTILS_DIR)/verible-verilog/verible-v0.0-3752-g8b64887e/bin/*
	mv $(CHIM_UTILS_DIR)/verible-verilog/verible-v0.0-3752-g8b64887e/bin/* $(CHIM_UTILS_DIR)/verible-verilog
	rm -rf $(CHIM_UTILS_DIR)/verible-verilog/verible-v0.0-3752-g8b64887e*

# Download padrick binary (only x86_64)
$(CHIM_UTILS_DIR)/padrick:
	$(call download_git_bin,$(CHIM_UTILS_DIR),pulp-platform/padrick,v0.3.6,Padrick-x86_64.AppImage)
	mv $(CHIM_UTILS_DIR)/Padrick-x86_64.AppImage $(CHIM_UTILS_DIR)/padrick
	chmod a+x $(CHIM_UTILS_DIR)/padrick

# Clean up
chim-utils-clean:
	rm -rf $(CHIM_UTILS_DIR)/verible-verilog
	rm -rf $(CHIM_UTILS_DIR)/padrick

endif # chim_utils_mk
