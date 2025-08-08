// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Sergio Mazzola <smazzola@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

// Test HyperRAM addressability through the Hyperbus peripheral

#include <soc_addr_map.h>
#include <stdint.h>

#define HYPER_BASE HYPERRAM_BASE
#define TESTVAL (uint32_t)0x1234ABCD

int main() {
    volatile uint8_t *regPtr = (volatile uint8_t *)SOC_CTRL_BASE;
    setAllClusterReset(regPtr, 0);
    setAllClusterClockGating(regPtr, 0);
    volatile uint32_t *hyperMemPtr = (volatile uint32_t *)HYPER_BASE;
    volatile uint32_t result;

    // write
    *(hyperMemPtr) = TESTVAL;
    // read
    result = *(hyperMemPtr);

    // verify
    if (result == TESTVAL) {
        return 0;
    } else {
        return 1;
    }
}
