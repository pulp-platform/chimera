# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>
# Lorenzo Leone <lleone@iis.ee.ethz.ch>


CLINTCORES = 46     # 1 + tot. #cores (e.g. 5 clusters * 9 cores + 1 = 46)
PLICCORES = 92      # 2 + 2 * tot. #cores (e.g. 2 * 5 clusters * 9 cores + 2 = 92)
PLIC_NUM_INTRS = 59 # 58 + ChsCfg.NumExtInIntrs + 1


.PHONY: update_plic
update_plic: $(CHS_ROOT)/hw/rv_plic.cfg.hjson
	sed -i 's/src: .*/src: $(PLIC_NUM_INTRS),/' $<
	sed -i 's/target: .*/target: $(PLICCORES),/' $<

# SCHEREMO: Technically, there exists a __deploy__* tag for the idma with fixes, but we're checking out the base version
gen_idma_hw:
	make -C $(IDMA_ROOT) idma_hw_all

CHS_SW_LD_DIR = $(CHIM_ROOT)/sw/link
CHS_SW_ADDRS_LDH = $(CHS_SW_LD_DIR)/chimera_addrs.ldh

$(CHS_SW_LD_DIR)/chimera_addrs.ldh: $(CHIM_ROOT)/cfg/rdl/chimera_addrmap.rdl $(CHS_SLINK_DIR)/.generated
	$(PEAKRDL) raw-header $< --format ldh $(PEAKRDL_INCLUDES) $(CHS_PEAKRDL_PARAMS) --no-prefix --license_str $$'Copyright 2025 ETH Zurich and University of Bologna.\nLicensed under the Apache License, Version 2.0, see LICENSE for details.\nSPDX-License-Identifier: Apache-2.0' -o $@

$(CHS_ROOT)/hw/bootrom/cheshire_bootrom.elf: $(CHS_SW_LD_DIR)/cheshire_bootrom.ld $(CHS_BROM_SRCS) $(CHS_SW_ADDRS_LDH)
	$(CHS_SW_CC) $(CHS_SW_INCLUDES) -T$< $(CHS_BROM_FLAGS) -o $@ $(CHS_BROM_SRCS)

.PHONY: chs-hw-init
chs-hw-init: update_plic gen_idma_hw ## Generate Cheshire RTL
	make -B chs-hw-all CHS_XLEN=$(CHS_XLEN) CHS_SW_LD_DIR=$(CHS_SW_LD_DIR)

##################
# Snitch Cluster #
##################

-include $(SN_ROOT)/make/common.mk
# Use the snitch toolchain to generate the cluster bootrom
-include $(SN_ROOT)/sw/toolchain.mk
-include $(SN_ROOT)/make/rtl.mk

# .PHONY: snitch-hw-init
.PHONY: sn-hw-clean sn-hw-all

sn-hw-all: sn-rtl ## Generate Snitch RTL
sn-hw-clean: sn-clean-rtl  ## Clean Snitch RTL

# NOTE: the SoC-control register block now comes from SystemRDL (cfg/rdl) via
# peakrdl (see rdl.mk `regenerate_soc_regs`); the lowRISC reggen flow
# (chimera_regs.hjson + utils/reggen) was retired. The Snitch bootrom sources
# now include the generated headers from .generated directly; the hand-kept
# sw/include/{regs/soc_ctrl.h,soc_addr_map.h,offload.h} were removed.


.PHONY: snitch_bootrom
CHIM_BROM_SRCS = $(wildcard $(CHIM_ROOT)/hw/bootrom/snitch/*.S $(CHIM_ROOT)/hw/bootrom/snitch/*.c)
CHIM_BROM_FLAGS = $(CHS_SW_LDFLAGS) -Os -fno-zero-initialized-in-bss -flto -fwhole-program -march=rv32im_zicsr -mabi=ilp32

CHIM_BOOTROM_ALL += $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.sv $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.dump

snitch_bootrom: $(CHIM_BOOTROM_ALL) ## Generate Snitch bootrom

# The bootrom sources include the SystemRDL-generated headers directly
# (.generated/{chimera_addrmap_raw,snitch_cluster_addrmap,snitch_cluster_cfg}.h),
# so add -I$(RDL_GEN_DIR) and ensure they are generated first (chim-rdl-raw-header
# + chim-rdl-sw-headers). The old hand-maintained sw/include headers were removed.
$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.elf: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.ld $(CHIM_BROM_SRCS) | chim-rdl-raw-header chim-rdl-sw-headers
	$(CHS_SW_CC) -I$(RDL_GEN_DIR) $(CHS_SW_INCLUDES) -T$< $(CHIM_BROM_FLAGS) -o $@ $(CHIM_BROM_SRCS)

$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.bin: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.elf
	$(CHS_SW_OBJCOPY) -O binary $< $@

$(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.sv: $(CHIM_ROOT)/hw/bootrom/snitch/snitch_bootrom.bin $(CHS_ROOT)/util/gen_bootrom.py
	$(CHS_ROOT)/util/gen_bootrom.py --sv-module chimera_snitch_bootrom $< > $@

.PHONY: regenerate_soc_regs
regenerate_soc_regs: chim-rdl-regblock ## Regenerate the SoC-control register block from SystemRDL (cfg/rdl)

-include $(CHIM_NONFREE_DIR)/nonfree.mk

-include $(CHIM_ROOT)/bender.mk

# Provides the Snitch bootrom compile flags (march/ABI)
-include $(CHIM_ROOT)/sw/sw.mk

# Include subdir Makefiles
-include $(CHIM_ROOT)/utils/utils.mk
# Include target makefiles
TB_DUT = tb_chimera_soc
-include $(CHIM_ROOT)/target/sim/sim.mk

#################################
# Phonies for the entire system #
#################################
CHIM_HW_ALL = chs-hw-init sn-hw-all chim-bootrom-init
CHIM_SW_ALL = chim-rdl chim-sw
CHIM_SIM_ALL = chim-sim
CHIM_ALL += $(CHIM_HW_ALL) $(CHIM_SW_ALL) $(CHIM_SIM_ALL)
CHIM_CLEAN += chim-rdl-clean chim-sw-clean chim-sim-clean sn-hw-clean

.PHONY: chim-all
chim-all: $(CHIM_ALL) ## Generate full chimera infrastructure

.PHONY: chim-clean
chim-clean: $(CHIM_CLEAN) ## Clean entire chimera infrastructure
