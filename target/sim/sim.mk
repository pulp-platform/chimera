# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>
# Sergio Mazzola <smazzola@iis.ee.ethz.ch>

ifndef chim_sim_mk
chim_sim_mk=1

CHIM_SIM_DIR ?= $(CHIM_ROOT)/target/sim

# Init vsim compilation
.PHONY: chim-sim
chim-sim: chim-hyperram-model $(CHIM_SIM_DIR)/vsim/compile.tcl

# Get HyperRAM verification IP (VIP) for simulation
.PHONY: chim-hyperram-model
chim-hyperram-model: $(CHIM_SIM_DIR)/models/s27ks0641/s27ks0641.sv
$(CHIM_SIM_DIR)/models/s27ks0641/s27ks0641.sv:
	make -C $(HYPERB_ROOT) models/s27ks0641
	mkdir -p $(dir $@)
	cp -r $(HYPERB_ROOT)/models/s27ks0641 $(CHIM_SIM_DIR)/models
# Defines for hyperram model preload at time 0
HYP_USER_PRELOAD      ?= 0
HYP0_PRELOAD_MEM_FILE ?= ""
HYP1_PRELOAD_MEM_FILE ?= ""

CHIM_VLOG_ARGS += +define+HYP_USER_PRELOAD="$(HYP_USER_PRELOAD)"
CHIM_VLOG_ARGS += +define+HYP0_PRELOAD_MEM_FILE=\"$(HYP0_PRELOAD_MEM_FILE)\"
CHIM_VLOG_ARGS += +define+HYP1_PRELOAD_MEM_FILE=\"$(HYP1_PRELOAD_MEM_FILE)\"
# this path should be kept relative to the vsim directory to avoid CI issues:
# an absolute path produce inter-CI-runner file accesses
CHIM_VLOG_ARGS += +define+PATH_TO_HYP_SDF=\"../models/s27ks0641/s27ks0641.sdf\"

# Generate vsim compilation script
$(CHIM_SIM_DIR)/vsim/compile.tcl: chs-hw-init snitch-hw-init
	@bender script vsim $(SIM_TARGS) --vlog-arg="$(CHIM_VLOG_ARGS)" > $@
	echo 'vlog "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@

# Clean
.PHONY: chim-sim-clean
chim-sim-clean:
	@rm -rf $(CHIM_SIM_DIR)/vsim/work
	@rm -rf $(CHIM_SIM_DIR)/vsim/transcript
	@rm -f $(CHIM_SIM_DIR)/vsim/compile.tcl

endif # chim_sim_mk
