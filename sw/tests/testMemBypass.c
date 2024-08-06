// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

// Test to check if clusters can access the memory island both using
// the wide interconnect and the narrow AXI.
// The following tests are executed:
//   - Write and Read configuration registers for all clusters
//   - Access the memory island both settin/disabling the bypass mode

#include <stdint.h>
#include "regs/soc_ctrl.h"
#include "offload.h"
#include "soc_addr_map.h"

//#define TOPLEVELREGION 0x30001000
#define NUMCLUSTERS 5
#define TESTNARROW 0x050CCE55
#define TESTWIDE 0x060CCE55

static uint32_t *clintPointer = (uint32_t *)CLINT_CTRL_BASE;

void clusterTrapHandler() {
    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    volatile uint32_t *interruptTarget = clintPointer + hartId;
    *interruptTarget = 0;
    return;
}

int32_t returnPtr(uint32_t ClstIdx) {
    int32_t regPtr;

    if (ClstIdx == 0) {
        regPtr = (SOC_CTRL_BASE + CHIMERA_WIDE_MEM_CLUSTER_1_BYPASS_REG_OFFSET);
    } else if (ClstIdx == 1) {
        regPtr = (SOC_CTRL_BASE + CHIMERA_WIDE_MEM_CLUSTER_2_BYPASS_REG_OFFSET);
    } else if (ClstIdx == 2) {
        regPtr = (SOC_CTRL_BASE + CHIMERA_WIDE_MEM_CLUSTER_3_BYPASS_REG_OFFSET);
    } else if (ClstIdx == 3) {
        regPtr = (SOC_CTRL_BASE + CHIMERA_WIDE_MEM_CLUSTER_4_BYPASS_REG_OFFSET);
    } else if (ClstIdx == 4) {
        regPtr = (SOC_CTRL_BASE + CHIMERA_WIDE_MEM_CLUSTER_5_BYPASS_REG_OFFSET);
    }
    return regPtr;
}

// Align function to make sure consecutive calls need to be fetched
int32_t __attribute__((aligned(32))) testMemNarrow() {
    return TESTNARROW;
}

int32_t __attribute__((aligned(32))) testMemWide() {
    return TESTWIDE;
}

int main() {
    volatile int32_t *regPtr = 0;

    uint32_t retVal = 0;

    // Tes for each cluster
    for (int ClstIdx = 0; ClstIdx < NUMCLUSTERS; ClstIdx++) {

        regPtr = (volatile int32_t *)returnPtr(ClstIdx);

        /* TEST RESET VALUE */
        if (*regPtr != 0) {
            return 1;
        }

        /* TEST WRITABILITY */
        *regPtr = 1;
        if (*regPtr != 1) {
            return 2;
        }
    }

    /* Offload Cluster 1 and Test NARROW PATH */
    regPtr = (volatile int32_t *)returnPtr(1);
    *regPtr = 1;
    setupInterruptHandler(clusterTrapHandler);
    offloadToCluster(testMemNarrow, 1);
    retVal = waitForCluster(1);

    if (retVal != TESTNARROW) {
        return 3;
    }

    /* Offload Cluster 2 and Test WIDE PATH */
    regPtr = (volatile int32_t *)returnPtr(2);
    *regPtr = 0;
    setupInterruptHandler(clusterTrapHandler);
    offloadToCluster(testMemWide, 2);
    retVal = waitForCluster(2);

    if (retVal != TESTWIDE) {
        return 4;
    }

    return 0;
}
