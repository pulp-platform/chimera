# ----------------------------------------------------------------------
#
# File: sim.mk
#
# Created: 25.06.2024        
# 
# Copyright (C) 2024, ETH Zurich and University of Bologna.
#
# Author: Moritz Scherer, ETH Zurich
#
# ----------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the License); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.PHONY: sim sim-clean

chim-sim-clean:
	@rm -rf target/sim/vsim/work
	@rm -rf target/sim/vsim/transcript
	@rm -f $(CHIM_ROOT)/target/sim/vsim/compile.tcl

chim-sim: $(CHIM_ROOT)/target/sim/vsim/compile.tcl

$(CHIM_ROOT)/target/sim/vsim/compile.tcl: chs-hw-init snitch-hw-init
	@bender script vsim $(COMMON_TARGS) $(SIM_TARGS) --vlog-arg="$(VLOG_ARGS)"> $@
	echo 'vlog "$(realpath $(CHS_ROOT))/target/sim/src/elfloader.cpp" -ccflags "-std=c++11"' >> $@

