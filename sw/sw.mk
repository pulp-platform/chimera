# Copyright 2024 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Moritz Scherer <scheremo@iis.ee.ethz.ch>
# Lorenzo Leone <lleone@iis.ee.ethz.ch>


ifndef chim_sw_mk
chim_sw_mk=1

##@ SoC Software (chimera-sdk)

# The SoC software is built by the chimera-sdk submodule with its own CMake flow
# inside the toolchain container (LLVM 18.1.4-pulp + picolibc). The remaining
# bootrom bits below only serve the Snitch bootrom (hw/bootrom/snitch), which now
# includes the SystemRDL-generated headers from .generated directly (the
# hand-maintained sw/include/{regs/soc_ctrl.h,soc_addr_map.h} were removed; the
# -I.generated is added in chimera.mk).

# --- Snitch bootrom flags ---
# SCHEREMO: use im as the smallest common denominator between CVA6 and the Snitch
# cluster; CVA6's bootrom needs imc, so override for that case.
CHS_SW_FLAGS   += -falign-functions=64 -march=rv64gc_zifencei -mabi=lp64d
CHS_BROM_FLAGS += -march=rv64gc_zifencei -mabi=lp64d

# --- chimera-sdk build configuration ---
CHIM_SDK_DIR             ?= $(CHIM_SW_DIR)/deps/chimera-sdk
CHIM_SDK_BUILD_DIR       ?= $(CHIM_SDK_DIR)/build
CHIM_SDK_TARGET_PLATFORM ?= chimera-open
CHIM_SDK_HW_BACKEND      ?= RTL
CHIM_SDK_UNIFIED_ELF     ?= ON
# Container-internal toolchain paths (provided by the image).
CHIM_SDK_TOOLCHAIN_DIR   ?= /app/install/llvm-18.1.4-pulp
CHIM_SDK_PICOLIBC_DIR    ?= /app/install/picolibc
# Container runner (honours CONTAINER_RUNTIME / CHIM_SDK_SIF / CHIM_SDK_IMAGE /
# CHIM_SDK_CACHE_DIR — see scripts/sdk_container.sh).
SDK_CONTAINER            ?= $(CHIM_ROOT)/scripts/sdk_container.sh

CHIM_SDK_CMAKE_ARGS = \
	-D TARGET_PLATFORM=$(CHIM_SDK_TARGET_PLATFORM) \
	-D TOOLCHAIN_DIR=$(CHIM_SDK_TOOLCHAIN_DIR) \
	-D PICOLIBC_DIR=$(CHIM_SDK_PICOLIBC_DIR) \
	-D HARDWARE_BACKEND=$(CHIM_SDK_HW_BACKEND) \
	-D CHIMERA_UNIFIED_ELF=$(CHIM_SDK_UNIFIED_ELF)

.PHONY: chim-sw chim-sw-init chim-sw-configure chim-sw-build chim-sw-shell chim-sw-clean

chim-sw-init: ## Init/update the chimera-sdk submodule (recursive)
	git -C $(CHIM_ROOT) submodule update --init --recursive $(CHIM_SDK_DIR)

chim-sw-configure: ## Configure the SoC software (chimera-sdk, CMake) in the container
	$(SDK_CONTAINER) "cmake $(CHIM_SDK_CMAKE_ARGS) -B build"

chim-sw-build: ## Build the SoC software (chimera-sdk) in the container
	$(SDK_CONTAINER) "cmake --build build -j"

chim-sw: chim-sw-configure chim-sw-build ## Configure + build the SoC software (chimera-sdk)

chim-sw-shell: ## Open an interactive shell in the toolchain container
	$(SDK_CONTAINER)

chim-sw-clean: ## Remove the chimera-sdk build directory
	rm -rf $(CHIM_SDK_BUILD_DIR)

##@ Testing (ctest + pytest)

# The SDK is configured with TEST_MODE=simulation and the chimera-top RTL sim as
# the SoC model (scripts/sim_runner.sh bridges to `make chim-run-batch`). ctest
# registers one case per test; pytest (test/) discovers and runs them with
# JUnit/HTML reporting. The SAME `make chim-test` runs locally and in CI.

CHIM_SDK_SIM_RUNNER   ?= $(CHIM_ROOT)/scripts/sim_runner.sh
CHIM_SDK_PRELOAD_MODE ?= 3
PYTEST                ?= $(CHIM_ROOT)/.venv/bin/python -m pytest

# Per-test wall-clock timeout (seconds), enforced in sim_runner.sh. Exported so it
# reaches the runner through the pytest -> ctest layers. Override: make chim-test SIM_TIMEOUT=300
SIM_TIMEOUT           ?= 60
export SIM_TIMEOUT

CHIM_SDK_SIM_CMAKE_ARGS = $(CHIM_SDK_CMAKE_ARGS) \
	-D TEST_MODE=simulation \
	-D SOC_MODEL_BINARY=$(CHIM_SDK_SIM_RUNNER) \
	-D PRELOAD_MODE=$(CHIM_SDK_PRELOAD_MODE)

# VERBOSE=1 -> per-test status (-v), no capture (-s), live vsim streaming.
# JOBS=<n|auto> -> run that many sims in parallel via pytest-xdist.
CHIM_TEST_FLAGS := $(PYTEST_EXTRA)
ifeq ($(VERBOSE),1)
CHIM_TEST_FLAGS += -v -s --sim-verbose
endif
ifdef JOBS
CHIM_TEST_FLAGS += -n $(JOBS)
endif

.PHONY: chim-test-configure chim-test chim-test-ctest

chim-test-configure: ## Configure chimera-sdk for RTL-sim testing (registers ctest cases)
	$(SDK_CONTAINER) "cmake $(CHIM_SDK_SIM_CMAKE_ARGS) -B build"

# Re-configure (sim mode) and rebuild before running, so the suite always
# exercises freshly-compiled ELFs (correct per-target ISA/ABI from the SDK).
chim-test: chim-test-configure chim-sw-build ## Build + run the SoC test suite (pytest); VERBOSE=1 for live output
	$(PYTEST) $(CHIM_ROOT)/test \
		--build-dir $(CHIM_SDK_BUILD_DIR) $(CHIM_TEST_FLAGS)

chim-test-ctest: ## Run the SoC test suite directly via ctest (no pytest)
	ctest --test-dir $(CHIM_SDK_BUILD_DIR) --output-on-failure $(CTEST_EXTRA)

##@ Bootrom

# The bootrom no longer depends on the SoC software (libchimera.a was removed).
.PHONY: chim-bootrom-init
chim-bootrom-init: chs-hw-init ## Generate SoC bootrom
	make -B chs-bootrom-all CHS_XLEN=$(CHS_XLEN) CHS_SW_LD_DIR=$(CHS_SW_LD_DIR)

endif # chim_sw_mk
