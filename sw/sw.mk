# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>
# Lorenzo Leone <lleone@iis.ee.ethz.ch>


ifndef chim_sw_mk
chim_sw_mk=1

CHS_SW_INCLUDES += -I$(CHIM_SW_DIR)/include


# SCHEREMO: use im for platform-level SW, as the smallest common denominator between CVA6 and the Snitch cluster.
# CVA6's bootrom however needs imc, so override that for this specific case.
CHS_SW_FLAGS += -falign-functions=64 -march=rv32im -mno-relax
CHS_BROM_FLAGS += -march=rv32imc -mrelax

CHS_SW_LDFLAGS += -L$(CHIM_SW_DIR)/lib -mno-relax

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

CHIM_SW_TESTS += $(CHIM_SW_TEST_MEMISL_DUMP)

# All objects require up-to-date patches and headers
%.o: %.c
	$(CHS_SW_CC) $(CHS_SW_INCLUDES) $(CHS_SW_CCFLAGS) -c $< -o $@

%.o: %.S
	$(CHS_SW_CC) $(CHS_SW_INCLUDES) $(CHS_SW_CCFLAGS) -c $< -o $@

define chim_sw_ld_elf_rule
.PRECIOUS: %.$(1).elf

%.$(1).elf: $$(CHS_SW_LD_DIR)/$(1).ld %.o $$(CHS_SW_LIBS)
	$$(CHS_SW_CC) $$(CHS_SW_INCLUDES) -T$$< $$(CHS_SW_LDFLAGS) -o $$@ $$*.o $$(CHS_SW_LIBS)
endef

$(foreach link,$(patsubst $(CHS_SW_LD_DIR)/%.ld,%,$(wildcard $(CHS_SW_LD_DIR)/*.ld)),$(eval $(call chim_sw_ld_elf_rule,$(link))))

chim-sw: $(CHIM_SW_LIB) $(CHIM_SW_TESTS)

.PHONY: chim-bootrom-init
chim-bootrom-init: chs-hw-init chim-sw
	make -B chs-bootrom-all CHS_XLEN=$(CHS_XLEN) CHS_SW_LD_DIR=$(CHS_SW_LD_DIR)


chim-sw-clean:
	@find sw/tests | grep ".*\.elf" | xargs -I ! rm !
	@find sw/tests | grep ".*\.dump" | xargs -I ! rm !
	@find sw/tests | grep ".*\.memh" | xargs -I ! rm !
	@find sw/lib | grep ".*\.a" | xargs -I ! rm !

endif # chim_sw_mk
