# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>
# Lorenzo Leone  <lleone@iis.ee.ethz.ch>
# Sergio Mazzola <smazzola@iis.ee.ethz.ch>

ifndef chim_sim_mk
chim_sim_mk=1

CHIM_SIM_DIR ?= $(CHIM_ROOT)/target/sim
VSIM_DIR 	?= $(CHIM_ROOT)/target/sim/vsim
VSIM 			?= vsim
VSIM_WORK ?= $(VSIM_DIR)/work
# Directory the simulation runs in; all per-run artifacts (trace_hart_*, dma_trace_*,
# transcript, modelsim.ini) are written to the cwd, so isolate them here. Defaults to
# the repo root (unchanged behaviour); sim_runner.sh overrides it per test.
RUN_DIR   ?= $(CHIM_ROOT)
CHIM_HYPERBUS_SDF_PATH ?= ./target/sim/models/s27ks0641/s27ks0641.sdf

CHIM_VLOG_ARGS += -work $(VSIM_WORK)
CHIM_VLOG_ARGS += -timescale 1ns/1ps
CHIM_VLOG_ARGS += -suppress 2741
CHIM_VLOG_ARGS += -suppress 2583
CHIM_VLOG_ARGS += -suppress 13314
CHIM_VLOG_ARGS += +define+HYP_USER_PRELOAD="$(HYP_USER_PRELOAD)"
CHIM_VLOG_ARGS += +define+HYP0_PRELOAD_MEM_FILE=\"$(HYP0_PRELOAD_MEM_FILE)\"
# this path should be kept relative to the vsim directory to avoid CI issues:
# an absolute path produce inter-CI-runner file accesses
CHIM_VLOG_ARGS += +define+PATH_TO_HYP_SDF=\"$(CHIM_HYPERBUS_SDF_PATH)\"

VSIM_FLAGS_GUI = -voptargs=+acc

# Pre-optimized design for PARALLEL-safe batch runs. `vsim <tb>` re-optimizes on
# every invocation and takes an *exclusive* lock on the work library, so parallel
# runs serialize on work/_lock (and time out). Optimizing once into a snapshot lets
# many `vsim <snapshot>` open it read-only concurrently.
VOPT         ?= vopt
CHIM_OPT_TOP ?= $(TB_DUT)_opt
VOPT_ARGS    += -work $(VSIM_WORK) -modelsimini $(CHIM_ROOT)/modelsim.ini

override VSIM_FLAGS += -work $(VSIM_WORK) -suppress 8386

# Set testbech parameters
define add_vsim_flag
ifdef $(1)
	override VSIM_FLAGS += +$(1)=$$($(1))
endif
endef

$(eval $(call add_vsim_flag,BINARY))
$(eval $(call add_vsim_flag,SELCFG))
$(eval $(call add_vsim_flag,BOOTMODE))
$(eval $(call add_vsim_flag,PRELMODE))
$(eval $(call add_vsim_flag,IMAGE))

# Init vsim compilation
.PHONY: chim-sim chim-compile chim-opt chim-run chim-run-batch
chim-sim: chim-hyperram-model chs-sim-all chim-compile chim-opt ## Compile Chimera SoC

.PHONY: chim-hyperram-model
chim-hyperram-model: $(CHIM_SIM_DIR)/models/s27ks0641/s27ks0641.sv ## Get HypperRAM VIP for simulation
$(CHIM_SIM_DIR)/models/s27ks0641/s27ks0641.sv:
	make -C $(HYPERB_ROOT) models/s27ks0641
	mkdir -p $(dir $@)
	cp -r $(HYPERB_ROOT)/models/s27ks0641 $(CHIM_SIM_DIR)/models


# Defines for hyperram model preload at time 0
HYP_USER_PRELOAD      ?= 0
HYP0_PRELOAD_MEM_FILE ?= ""

# Generate vsim compilation script
$(CHIM_SIM_DIR)/vsim/compile.tcl: $(BENDER_YML) $(BENDER_LOCK)
	$(BENDER) script vsim $(SIM_TARGS) --vlog-arg="$(CHIM_VLOG_ARGS)" > $@
	echo 'vlog -work $(VSIM_WORK) "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@

# Compiler the design
chim-compile: $(CHIM_SIM_DIR)/vsim/compile.tcl $(CHIM_HW_ALL)
	$(VSIM) -c $(VSIM_FLAGS) -do "source $<; quit"

# Optimize once into a read-only snapshot so batch runs can execute in parallel.
chim-opt: ## Optimize the compiled design into a parallel-safe snapshot ($(CHIM_OPT_TOP))
	$(VOPT) $(VOPT_ARGS) $(TB_DUT) -o $(CHIM_OPT_TOP)

# Run simulation with GUI
chim-run: ## Run simulation with GUI
	mkdir -p $(RUN_DIR)
	cd $(RUN_DIR) && $(VSIM) $(VSIM_FLAGS) $(VSIM_FLAGS_GUI) -modelsimini $(CHIM_ROOT)/modelsim.ini $(TB_DUT) -do "log -r /*"

# Run simulation in batch mode
chim-run-batch: ## Run simulation in command line mode (read-only opt snapshot; parallel-safe)
	mkdir -p $(RUN_DIR)
	cd $(RUN_DIR) && $(VSIM) -c $(VSIM_FLAGS) -modelsimini $(CHIM_ROOT)/modelsim.ini $(CHIM_OPT_TOP) -do "run -all; quit"


# Clean
.PHONY: chim-sim-clean
chim-sim-clean: ## Clean RTL simulation files
	@rm -rf $(VSIM_WORK)
	@rm -rf $(VSIM_DIR)/transcript
	@rm -f $(VSIM_DIR)/compile.tcl

endif # chim_sim_mk
