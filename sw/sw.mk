# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>

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

CHIM_SW_TEST_MEMISL_DUMP = $(CHIM_SW_TEST_SRCS_S:.S=.memisl.dump)  $(CHIM_SW_TEST_SRCS_C:.c=.memisl.dump)

CHIM_SW_TESTS += $(CHIM_SW_TEST_DRAM_DUMP) $(CHIM_SW_TEST_SPM_DUMP) $(CHIM_SW_TEST_MEMISL_DUMP) $(CHIM_SW_TEST_SPM_ROMH) $(CHIM_SW_TEST_SPM_GPTH)

chim-sw: $(CHIM_SW_LIB) $(CHIM_SW_TESTS)

chim-sw-clean:
	@find sw/tests | grep ".*\.elf" | xargs -I ! rm !
	@find sw/tests | grep ".*\.dump" | xargs -I ! rm !
	@find sw/tests | grep ".*\.memh" | xargs -I ! rm !
	@find sw/lib | grep ".*\.a" | xargs -I ! rm !
