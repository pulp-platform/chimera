# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>

ifndef chim_sim_mk
chim_sim_mk=1

CHIM_SIM_DIR ?= $(CHIM_ROOT)/target/sim

.PHONY: sim sim-clean

chim-sim-clean:
	@rm -rf $(CHIM_SIM_DIR)/vsim/work
	@rm -rf $(CHIM_SIM_DIR)/vsim/transcript
	@rm -f $(CHIM_SIM_DIR)/vsim/compile.tcl

chim-sim: $(CHIM_SIM_DIR)/vsim/compile.tcl


$(CHIM_SIM_DIR)/vsim/compile.tcl: chs-hw-init snitch-hw-init
	@bender script vsim $(COMMON_TARGS) $(SIM_TARGS) $(EXT_TARGS) --vlog-arg="$(VLOG_ARGS)"> $@
	echo 'vlog "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@

endif # chim_sim_mk
