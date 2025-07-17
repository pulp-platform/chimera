#!/bin/bash
# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

export VSIM="questa-2022.3 vsim"
export VOPT="questa-2022.3 vopt"
export VLIB="questa-2022.3 vlib"
export BASE_PYTHON=/usr/local/anaconda3/bin/python3.11
export CHS_SW_GCC_BINROOT=/usr/pack/riscv-1.0-kgf/riscv64-gcc-12.2.0/bin
export LLVM_BINROOT=/usr/scratch2/vulcano/colluca/tools/riscv32-snitch-llvm-almalinux8-15.0.0-snitch-0.2.0/bin
export RISCV_GCC_BINROOT=/usr/pack/riscv-1.0-kgf/pulp-gcc-2.5.0/bin
export CC=/usr/pack/gcc-11.2.0-af/linux-x64/bin/gcc
export CXX=/usr/pack/gcc-11.2.0-af/linux-x64/bin/g++
export CMAKE=cmake-3.28.3

# Create the python venv
if [ ! -d ".venv" ]; then
  make python-venv
fi

# Activate the python venv only if not already active
if [ -z "$VIRTUAL_ENV" ] || [ "$VIRTUAL_ENV" != "$(realpath .venv)" ]; then
  source .venv/bin/activate
fi