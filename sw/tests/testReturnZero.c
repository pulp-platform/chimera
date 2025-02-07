// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

#include <soc_addr_map.h>
#include <stdint.h>

int main() {
    volatile uint8_t *clockGatingRegPtr = (volatile uint8_t *)SOC_CTRL_BASE;
    setAllClusterClockGating(clockGatingRegPtr, 1);

    return 0;
}