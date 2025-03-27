// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

// Simple offload test. Set the trap handler first, offload a function, retrieve
// return value from cluster. Does not currently take care of stack
// initialization and bss initialization on cluster.

#include "offload.h"
#include "soc_addr_map.h"
#include <regs/soc_ctrl.h>
#include <stdint.h>

#define TESTVAL 0x050CCE55

static uint32_t *clintPointer = (uint32_t *)CLINT_CTRL_BASE;

void clusterTrapHandler() {
    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    volatile uint32_t *interruptTarget = clintPointer + hartId;
    *interruptTarget = 0;
    return;
}

int32_t testReturn() {
    return TESTVAL;
}

int main() {
    volatile uint8_t *regPtr = (volatile uint8_t *)SOC_CTRL_BASE;
    setupInterruptHandler(clusterTrapHandler);

    uint32_t retVal = 0;
    for (int i = 0; i < _chimera_numClusters; i++) {
        setClusterReset(regPtr, i, 0);
        setClusterClockGating(regPtr, i, 0);
        offloadToCluster(testReturn, i);
        retVal |= waitForCluster(i);
        setClusterClockGating(regPtr, i, 1);
        setClusterReset(regPtr, i, 0);
    }

    return (retVal != (TESTVAL | 0x000000001));
}
