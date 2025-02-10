// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleoen@iis.ee.ethz.ch>

#include <soc_addr_map.h>
#include "regs/soc_ctrl.h"
#include <stdint.h>
#include <stdbool.h>

#define TESTVAL 0x00E0D0C0
#define RSTVAL 0x30000000

int main() {
    volatile uint32_t *regPtr = (volatile uint32_t *)SOC_CTRL_BASE;
    uint32_t regVal = 0;
    uint32_t regOffset = CHIMERA_SNITCH_CONFIGURABLE_BOOT_ADDR_REG_OFFSET / 4;

    // Check if configurable boot address reset value is the expected one: 0x30000000
    regVal = *(regPtr + regOffset);
    if (regVal != RSTVAL) {
        return 1;
    }

    // Write a TESTVAL and check the write was succesfull
    *(regPtr + regOffset) = TESTVAL;
    regVal = *(regPtr + regOffset);
    if (regVal != TESTVAL) {
        return 2;
    }

    // Write the original value again and disable cluster clock gating to check correct boot
    // wait 100 cycles to see boot access from, the waveforms.
    *(regPtr + regOffset) = RSTVAL;
    setAllClusterReset(regPtr, 0);
    setAllClusterClockGating(regPtr, 0);

    for (int i = 0; i < 100; i++) {
        // NOP
        asm volatile("addi x0, x0, 0\n" :::);
    }

    return 0;
}
