# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

##@ SystemRDL (global memory map / registers)

# Single source of truth for the SoC memory map and control registers lives in
# cfg/rdl/*.rdl and is rendered with peakrdl (declared in pyproject.toml). This
# replaces the hand-maintained duplication across hw/chimera_pkg.sv,
# sw/include/soc_addr_map.h and the lowRISC-reggen register block.
# See docs/memory-map.md for the migration plan.

PEAKRDL      ?= $(CHIM_ROOT)/.venv/bin/peakrdl
RDL_DIR      ?= $(CHIM_ROOT)/cfg/rdl
RDL_GEN_DIR  ?= $(CHIM_ROOT)/.generated
RDL_TOP      ?= $(RDL_DIR)/chimera_addrmap.rdl
RDL_REGS     ?= $(RDL_DIR)/chimera_soc_regs.rdl
DOCS_ADDRMAP ?= $(CHIM_ROOT)/docs/addressmap.md
NUMCLUSTERS  ?= 5

# The top address map includes the real per-cluster map shipped by the
# snitch_cluster dependency (hw/generated/snitch_cluster.rdl, which itself
# includes snitch_cluster_peripheral_reg.rdl). Resolve those include dirs from
# the dependency checkout via `bender path` (Gwaihir-style), so peakrdl finds
# them in place without copying anything.
PEAKRDL_INCLUDES  = -I $(RDL_DIR)
ifneq ($(SN_ROOT),)
PEAKRDL_INCLUDES += -I $(SN_ROOT)/hw/generated
PEAKRDL_INCLUDES += -I $(SN_ROOT)/hw/snitch_cluster/src/snitch_cluster_peripheral
endif

ifneq ($(CHS_ROOT),)
PEAKRDL_INCLUDES += $(CHS_PEAKRDL_INCLUDES)
endif

.PHONY: rdl rdl-markdown rdl-c-header rdl-raw-header rdl-sw-headers rdl-regblock rdl-clean

$(RDL_GEN_DIR):
	mkdir -p $@

rdl-markdown: | $(RDL_GEN_DIR) ## Generate the global address-map Markdown (docs/addressmap.md)
	$(PEAKRDL) markdown $(RDL_TOP) $(PEAKRDL_INCLUDES) -o $(DOCS_ADDRMAP)

rdl-c-header: | $(RDL_GEN_DIR) ## Generate the SoC address-map register C header
	$(PEAKRDL) c-header $(RDL_TOP) $(PEAKRDL_INCLUDES) -o $(RDL_GEN_DIR)/chimera_addrmap.h

rdl-raw-header: | $(RDL_GEN_DIR) ## Generate SV + C address-map base-address headers
	$(PEAKRDL) raw-header $(RDL_TOP) $(PEAKRDL_INCLUDES) --format svh -o $(RDL_GEN_DIR)/chimera_addrmap.svh
	$(PEAKRDL) raw-header $(RDL_TOP) $(PEAKRDL_INCLUDES) --format c   -o $(RDL_GEN_DIR)/chimera_addrmap_raw.h

RDL_REG_OUT ?= $(CHIM_ROOT)/hw/regs
rdl-regblock: ## Generate the SoC-control SV register block into hw/regs (replaces reggen)
	$(PEAKRDL) regblock $(RDL_REGS) -o $(RDL_REG_OUT) --cpuif apb4-flat --default-reset arst_n \
		--module-name chimera_reg_top --package-name chimera_reg_pkg -P NrClusters=$(NUMCLUSTERS)
	@for f in $(RDL_REG_OUT)/chimera_reg_pkg.sv $(RDL_REG_OUT)/chimera_reg_top.sv; do \
		sed -i '1i// Copyright 2024 ETH Zurich and University of Bologna.\n// Licensed under the Apache License, Version 2.0, see LICENSE for details.\n// SPDX-License-Identifier: Apache-2.0\n' $$f; done

# Snitch cluster SW headers needed by the Snitch bootrom: the cluster config
# (CFG_CLUSTER_NR_CORES / SNRT_CLUSTER_NUM) and the cluster-local address map.
# Rendered by the vendored snitch-sdk clustergen from chimera's cluster config
# (5 clusters, host hart 0; see cfg/snitch_cluster.hjson).
RDL_PYTHON    ?= $(dir $(PEAKRDL))python
SN_SDK_DIR    ?= $(CHIM_SDK_DIR)/devices/snitch_cluster/third_party/snitch-sdk
SN_SDK_DEV    ?= $(SN_SDK_DIR)/devices/snitch_cluster
SN_CLUSTER_CFG?= $(CHIM_ROOT)/cfg/snitch_cluster.hjson
SN_CLUSTERGEN ?= $(SN_SDK_DIR)/scripts/clustergen.py

rdl-sw-headers: | $(RDL_GEN_DIR) ## Generate the Snitch cluster SW headers (cfg + addrmap)
	$(RDL_PYTHON) $(SN_CLUSTERGEN) --clustercfg $(SN_CLUSTER_CFG) \
		--template $(SN_SDK_DEV)/templates/snitch_cluster_cfg.h.tpl     --outdir $(RDL_GEN_DIR)
	$(RDL_PYTHON) $(SN_CLUSTERGEN) --clustercfg $(SN_CLUSTER_CFG) \
		--template $(SN_SDK_DEV)/templates/snitch_cluster_addrmap.h.tpl --outdir $(RDL_GEN_DIR)

rdl: rdl-markdown rdl-c-header rdl-raw-header rdl-sw-headers ## Generate the memory-map artifacts

rdl-clean: ## Remove generated SystemRDL artifacts
	rm -rf $(RDL_GEN_DIR) $(DOCS_ADDRMAP)
