# ----------------------------------------------------------------------
#
# File: sw.mk
#
# Created: 26.06.2024        
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

CHS_SW_INCLUDES += -I$(CHIM_SW_DIR)/include
CHS_SW_FLAGS += -falign-functions=64 -march=rv32im
CHS_SW_LDFLAGS += -L$(CHIM_SW_DIR)/lib

CHIM_SW_LIB_SRCS_C  = $(wildcard $(CHIM_SW_DIR)/lib/*.c $(CHIM_SW_DIR)/lib/**/*.c)
CHIM_SW_LIB_SRCS_O  = $(CHIM_SW_DEPS_SRCS:.c=.o) $(CHIM_SW_LIB_SRCS_S:.S=.o) $(CHIM_SW_LIB_SRCS_C:.c=.o)

CHIM_SW_LIB = $(CHIM_SW_DIR)/lib/libchimera.a
CHS_SW_LIBS += $(CHIM_SW_LIB)

$(CHIM_SW_DIR)/lib/libchimera.a: $(CHIM_SW_LIB_SRCS_O)
	rm -f $@
	$(CHS_SW_AR) $(CHS_SW_ARFLAGS) -rcsv $@ $^


CHIM_SW_TEST_SRCS_S 	 	= $(wildcard $(CHIM_SW_DIR)/tests/*.S)
CHIM_SW_TEST_SRCS_C     	= $(wildcard $(CHIM_SW_DIR)/tests/*.c)

CHIM_SW_TEST_DRAM_DUMP  	= $(CHIM_SW_TEST_SRCS_S:.S=.dram.dump) $(CHIM_SW_TEST_SRCS_C:.c=.dram.dump)
CHIM_SW_TEST_SPM_DUMP   	= $(CHIM_SW_TEST_SRCS_S:.S=.spm.dump)  $(CHIM_SW_TEST_SRCS_C:.c=.spm.dump)
CHIM_SW_TEST_MEMISL_DUMP = $(CHIM_SW_TEST_SRCS_S:.S=.memisl.dump)  $(CHIM_SW_TEST_SRCS_C:.c=.memisl.dump)
CHIM_SW_TEST_SPM_ROMH   	= $(CHIM_SW_TEST_SRCS_S:.S=.rom.memh)  $(CHIM_SW_TEST_SRCS_C:.c=.rom.memh)
CHIM_SW_TEST_SPM_GPTH   	= $(CHIM_SW_TEST_SRCS_S:.S=.gpt.memh)  $(CHIM_SW_TEST_SRCS_C:.c=.gpt.memh)

CHIM_SW_TESTS += $(CHIM_SW_TEST_DRAM_DUMP) $(CHIM_SW_TEST_SPM_DUMP) $(CHIM_SW_TEST_MEMISL_DUMP) $(CHIM_SW_TEST_SPM_ROMH) $(CHIM_SW_TEST_SPM_GPTH)

chim-sw: $(CHIM_SW_LIB) $(CHIM_SW_TESTS)

