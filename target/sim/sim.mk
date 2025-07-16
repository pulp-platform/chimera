# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>
# Sergio Mazzola <smazzola@iis.ee.ethz.ch>

ifndef chim_sim_mk
chim_sim_mk=1

CHIM_SIM_DIR ?= $(CHIM_ROOT)/target/sim
VSIM_DIR 	?= $(CHIM_ROOT)/target/sim/vsim
VSIM 			?= vsim
VSIM_WORK ?= $(VSIM_DIR)/work

CHIM_VLOG_ARGS += -timescale 1ns/1ps
CHIM_VLOG_ARGS += -suppress 2741
CHIM_VLOG_ARGS += -suppress 2583
CHIM_VLOG_ARGS += -suppress 13314
CHIM_VLOG_ARGS += +define+HYP_USER_PRELOAD="$(HYP_USER_PRELOAD)"
CHIM_VLOG_ARGS += +define+HYP0_PRELOAD_MEM_FILE=\"$(HYP0_PRELOAD_MEM_FILE)\"
# this path should be kept relative to the vsim directory to avoid CI issues:
# an absolute path produce inter-CI-runner file accesses
CHIM_VLOG_ARGS += +define+PATH_TO_HYP_SDF=\"../models/s27ks0641/s27ks0641.sdf\"

VSIM_FLAGS_GUI = -voptargs=+acc

# Set testbech parameters
define add_vsim_flag
ifdef $(1)
	VSIM_FLAGS += +$(1)=$$($(1))
endif
endef

$(eval $(call add_vsim_flag,BINARY))
$(eval $(call add_vsim_flag,SELCFG))
$(eval $(call add_vsim_flag,BOOTMODE))
$(eval $(call add_vsim_flag,PRELMODE))
$(eval $(call add_vsim_flag,IMAGE))

# Init vsim compilation
.PHONY: chim-sim chim-compile chim-run chim-run-batch
chim-sim: chim-hyperram-model chim-compile $(CHIM_ALL) ## Compile Chimera SoC

# Get HyperRAM verification IP (VIP) for simulation
.PHONY: chim-hyperram-model
chim-hyperram-model: $(CHIM_SIM_DIR)/models/s27ks0641/s27ks0641.sv
$(CHIM_SIM_DIR)/models/s27ks0641/s27ks0641.sv:
	# make -C $(HYPERB_ROOT) models/s27ks0641
	mkdir -p $(dir $@)
#TODO: This is an hotfix, change when https://github.com/pulp-platform/hyperbus/issues/22 is solved
	cp -r /usr/scratch/simba/lleone/InvecasHyper/models/s27ks0641 $(CHIM_SIM_DIR)/models

# Defines for hyperram model preload at time 0
HYP_USER_PRELOAD      ?= 0
HYP0_PRELOAD_MEM_FILE ?= ""

# Generate vsim compilation script
$(CHIM_SIM_DIR)/vsim/compile.tcl: $(BENDER_YML) $(BENDER_LOCK)
	@bender script vsim $(SIM_TARGS) --vlog-arg="$(CHIM_VLOG_ARGS)" > $@
	echo 'vlog "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@

# Compiler the design
chim-compile: $(CHIM_SIM_DIR)/vsim/compile.tcl $(CHIM_HW_ALL)
	$(VSIM) -c $(VSIM_FLAGS) -do "source $<; quit"

# Run simulation with GUI
chim-run: ## Run simulation with GUI
	$(VSIM) $(VSIM_FLAGS) $(VSIM_FLAGS_GUI) $(TB_DUT) -do "log -r /*"

# Run simulation in batch mode
chim-run-batch: ## Run simulation in batch mode
	$(VSIM) -c $(VSIM_FLAGS) $(TB_DUT) -do "run -all; quit"


# Clean
.PHONY: chim-sim-clean
chim-sim-clean: ## Clean RTL simulation files
	@rm -rf $(VSIM_WORK)
	@rm -rf $(VSIM_DIR)/transcript
	@rm -f $(VSIM_DIR)/compile.tcl

endif # chim_sim_mk
