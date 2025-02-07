// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

// This test aims to check if the clock gating registers
// inside Cheshire can be correctly driven from Chimera.
// The test is not automated; each peripheral's clock
// signal must be manually checked by looking at the waveforms.

#include <stdint.h>
#include "offload.h"
#include "regs/cheshire.h"
#include "soc_addr_map.h"

#define CHESHIRE_REGS_BASE 0x03000000

int main() {
    volatile uint8_t *clockGatingRegPtr = (volatile uint8_t *)SOC_CTRL_BASE;
    setAllClusterClockGating(clockGatingRegPtr, 0);

    volatile uint32_t *regPtr = 0;
    uint8_t expVal;

    regPtr =
        (volatile uint32_t *)(CHESHIRE_REGS_BASE + CHESHIRE_CLK_GATE_EN_PERIPHERALS_REG_OFFSET);

    // |------------------------------|
    // |        READ RST VALUE        |
    // |------------------------------|
    if (*regPtr != 0) return 1;

    // |------------------------------|
    // |       ENABLE CLK GATE        |
    // |------------------------------|
    expVal = 0x00007F;
    *regPtr |= expVal;
    if (*regPtr ^ expVal) return 2;

    // |------------------------------|
    // |       DISABLE CLK GATE       |
    // |------------------------------|
    expVal = 0x0000;
    *regPtr &= expVal;
    if (*regPtr ^ expVal) return 3;

    return 0;
}
