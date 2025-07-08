// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleoen@iis.ee.ethz.ch>

#include <soc_addr_map.h>
#include <chimera_addrmap.h>
#include "offload.h"
#include <stdint.h>
#include <stdbool.h>

#define TESTVAL 0x00E0D0FF
#define RSTVAL 0x30000000
#define NUMCLUSTERS 5

int main() {
    uint32_t regVal = 0;
    volatile uint32_t *cfgBootAddr =
        (volatile uint32_t *)&chimera_addrmap.host.chimera_regs.snitch_configurable_boot_addr;

    // Check if configurable boot address reset value is the expected one: 0x30000000
    regVal = *(cfgBootAddr);
    if (regVal != RSTVAL) {
        return 1;
    }

    // Write a TESTVAL and check the write was succesfull
    *(cfgBootAddr) = TESTVAL;
    regVal = *(cfgBootAddr);
    if (regVal != TESTVAL) {
        return 2;
    }

    // Write the original value again and disable cluster clock gating to check correct boot
    // wait 100 cycles to see boot access from, the waveforms.
    *(cfgBootAddr) = RSTVAL;
    setAllClusterReset(NUMCLUSTERS, 0);
    setAllClusterClockGating(NUMCLUSTERS, 0);

    for (int i = 0; i < 100; i++) {
        // NOP
        asm volatile("addi x0, x0, 0\n" :::);
    }

    return 0;
}
