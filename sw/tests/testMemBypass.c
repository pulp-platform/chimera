// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

// Test to check if clusters can access the memory island both using
// the wide interconnect and the narrow AXI.
// The following tests are executed:
//   - Write and Read configuration registers for all clusters
//   - Access the memory island both settin/disabling the bypass mode

#include <stdint.h>
#include "offload.h"
#include <chimera_addrmap.h>
#include "soc_addr_map.h"

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

int32_t *returnPtr(uint32_t clusterIdx) {
    int32_t *regPtr;
    regPtr = (int32_t *)&chimera_addrmap.host.chimera_regs.wide_mem_cluster_bypass[clusterIdx];

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

    setAllClusterReset(NUMCLUSTERS, 0);
    setAllClusterClockGating(NUMCLUSTERS, 0);

    volatile int32_t *regPtr = 0;

    uint32_t retVal = 0;

    // Tes for each cluster
    for (int clusterIdx = 0; clusterIdx < NUMCLUSTERS; clusterIdx++) {

        regPtr = (volatile int32_t *)returnPtr(clusterIdx);

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
    offloadToCluster(testMemNarrow, 0);
    retVal = waitForCluster(0);

    if (retVal != TESTNARROW) {
        return 3;
    }

    /* Offload Cluster 2 and Test WIDE PATH */
    regPtr = (volatile int32_t *)returnPtr(2);
    *regPtr = 0;
    setupInterruptHandler(clusterTrapHandler);
    offloadToCluster(testMemWide, 1);
    retVal = waitForCluster(1);

    if (retVal != TESTWIDE) {
        return 4;
    }

    return 0;
}
