# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>


CLINTCORES = 46
PLICCORES = 92
PLIC_NUM_INTRS = 92

.PHONY: update_plic
update_plic: $(CHS_ROOT)/hw/rv_plic.cfg.hjson
	sed -i 's/src: .*/src: $(PLIC_NUM_INTRS),/' $<
	sed -i 's/target: .*/target: $(PLICCORES),/' $<

# SCHEREMO: Technically, there exists a __deploy__* tag for the idma with fixes, but we're checking out the base version
gen_idma_hw:
	make -C $(IDMA_ROOT) idma_hw_all

CHS_SW_LD_DIR = $(CHIM_ROOT)/sw/link

.PHONY: chs-hw-init
chs-hw-init: update_plic gen_idma_hw $(CHIM_SW_LIB)
	make -B chs-hw-all CHS_XLEN=$(CHS_XLEN) CHS_SW_LD_DIR=$(CHS_SW_LD_DIR)

.PHONY: snitch-hw-init
snitch-hw-init:
	make -C $(SNITCH_ROOT)/target/snitch_cluster bin/snitch_cluster.vsim

.PHONY: $(CHIM_SW_DIR)/include/regs/soc_ctrl.h
$(CHIM_SW_DIR)/include/regs/soc_ctrl.h: $(CHIM_ROOT)/hw/regs/chimera_regs.hjson
	python $(CHIM_ROOT)/utils/reggen/regtool.py -D $<  > $@

.PHONY: $(CHIM_SW_DIR)/hw/regs/pcr.md
$(CHIM_HW_DIR)/regs/pcr.md: $(CHIM_ROOT)/hw/regs/chimera_regs.hjson
	python $(CHIM_ROOT)/utils/reggen/regtool.py -d $<  > $@


.PHONY: snitch_bootrom
CHIM_BROM_SRCS = $(wildcard $(CHIM_ROOT)/hw/bootrom/snitch/*.S $(CHIM_ROOT)/hw/bootrom/snitch/*.c) $(CHIM_SW_LIBS)
CHIM_BROM_FLAGS = $(CHS_SW_LDFLAGS) -Os -fno-zero-initialized-in-bss -flto -fwhole-program -march=rv32im

CHIM_BOOTROM_ALL += $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.sv $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.dump

snitch_bootrom: $(CHIM_BOOTROM_ALL)

$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.elf: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.ld $(CHIM_BROM_SRCS)
	$(CHS_SW_CC) -I$(CHIM_SW_DIR)/include/regs $(CHS_SW_INCLUDES) -T$< $(CHIM_BROM_FLAGS) -o $@ $(CHIM_BROM_SRCS)

$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.bin: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.elf
	$(CHS_SW_OBJCOPY) -O binary $< $@

$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.sv: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.bin $(CHS_ROOT)/util/gen_bootrom.py
	$(CHS_ROOT)/util/gen_bootrom.py --sv-module snitch_bootrom $< > $@

.PHONY: regenerate_soc_regs
regenerate_soc_regs: $(CHIM_ROOT)/hw/regs/chimera_reg_pkg.sv $(CHIM_ROOT)/hw/regs/chimera_reg_top.sv $(CHIM_SW_DIR)/include/regs/soc_ctrl.h $(CHIM_HW_DIR)/regs/pcr.md

.PHONY: $(CHIM_ROOT)/hw/regs/chimera_reg_pkg.sv hw/regs/chimera_reg_top.sv
$(CHIM_ROOT)/hw/regs/chimera_reg_pkg.sv $(CHIM_ROOT)/hw/regs/chimera_reg_top.sv: $(CHIM_ROOT)/hw/regs/chimera_regs.hjson
	python $(CHIM_ROOT)/utils/reggen/regtool.py -r $< --outdir $(dir $@)


# Nonfree components
CHIM_NONFREE_REMOTE ?= git@iis-git.ee.ethz.ch:pulp-restricted/chimera-nonfree.git
CHIM_NONFREE_DIR ?= $(CHIM_ROOT)/nonfree
CHIM_NONFREE_COMMIT ?= deploy # to deploy `chimera-nonfree` repo changes, push to `deploy` tag

.PHONY: chim-nonfree-init
chim-nonfree-init:
	git clone $(CHIM_NONFREE_REMOTE) $(CHIM_NONFREE_DIR)
	cd $(CHIM_NONFREE_DIR) && git checkout $(CHIM_NONFREE_COMMIT)

-include $(CHIM_NONFREE_DIR)/nonfree.mk

-include $(CHIM_ROOT)/bender.mk

# Necessary to build libchimera.a for bootrom.elf
# TODO: Here the make chim-sw cannot work properly FIND SOLUTION !!!!!
-include $(CHIM_ROOT)/sw/sw.mk

# Include subdir Makefiles
-include $(CHIM_ROOT)/utils/utils.mk
# Include target makefiles
-include $(CHIM_ROOT)/target/sim/sim.mk
