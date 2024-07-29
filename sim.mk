# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>

.PHONY: sim sim-clean

chim-sim-clean:
	@rm -rf target/sim/vsim/work
	@rm -rf target/sim/vsim/transcript
	@rm -f $(CHIM_ROOT)/target/sim/vsim/compile.tcl

chim-sim: $(CHIM_ROOT)/target/sim/vsim/compile.tcl

$(CHIM_ROOT)/target/sim/vsim/compile.tcl: chs-hw-init snitch-hw-init
	@bender script vsim $(COMMON_TARGS) $(SIM_TARGS) --vlog-arg="$(VLOG_ARGS)"> $@
	echo 'vlog "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@

