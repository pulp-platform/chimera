#!/usr/bin/env bash

# Copyright 2024 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Sergio Mazzola <smazzola@iis.ee.ethz.ch>

# Parse the number of errors from the last occurrence in the transcript
RET=$(grep -Po '(?<=Errors: )\d+' "$1" | tail -n 1)
# Check if pattern not found
[[ -z "${RET}" ]] && echo "Simulation did not finish or no errors found" && exit 1

# Return with the number of errors
echo "Simulation returned ${RET} errors"
[[ "${RET}" -eq 0 ]] && exit 0 || exit 1
