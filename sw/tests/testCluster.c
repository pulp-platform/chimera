// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

#include <soc_addr_map.h>
#include <stdint.h>

#define CLUSTERMEMORYSTART CLUSTER_0_BASE
#define CLUSTERDISTANCE (CLUSTER_1_BASE - CLUSTER_0_BASE)
#define NUMCLUSTERS 5

#define TESTVAL 0x00E0D0C0

int main() {
    volatile uint8_t *clockGatingRegPtr = (volatile uint8_t *)SOC_CTRL_BASE;
    setAllClusterClockGating(clockGatingRegPtr, 1);

    volatile int32_t *clusterMemPtr = (volatile int32_t *)CLUSTERMEMORYSTART;
    volatile int32_t result;

    uint8_t ret = 0;
    for (int i = 0; i < NUMCLUSTERS; i++) {
        *(clusterMemPtr) = TESTVAL;
        clusterMemPtr += CLUSTERDISTANCE / 4;
    }

    clusterMemPtr = (volatile int32_t *)CLUSTERMEMORYSTART;
    for (int i = 0; i < NUMCLUSTERS; i++) {
        result = *(clusterMemPtr);
        if (result == TESTVAL) {
            ret += 1;
        } else {
            ret += 1 << (NUMCLUSTERS + i);
        }
        clusterMemPtr += CLUSTERDISTANCE / 4;
    }

    if ((ret & ((1 << NUMCLUSTERS) - 1)) == NUMCLUSTERS) {
        return 0;
    }

    return ret;
}
