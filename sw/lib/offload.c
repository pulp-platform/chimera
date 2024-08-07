// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

#include "regs/soc_ctrl.h"
#include "soc_addr_map.h"
#include <stdint.h>

void setupInterruptHandler(void *handler) {
    volatile void **snitchTrapHandlerAddr =
        (volatile void **)(SOC_CTRL_BASE + CHIMERA_SNITCH_INTR_HANDLER_ADDR_REG_OFFSET);

    *snitchTrapHandlerAddr = handler;
}

void waitClusterBusy(uint8_t clusterId) {
    volatile int32_t *busy_ptr;

    if (clusterId == 0) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_1_BUSY_REG_OFFSET);
    } else if (clusterId == 1) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_2_BUSY_REG_OFFSET);
    } else if (clusterId == 2) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_3_BUSY_REG_OFFSET);
    } else if (clusterId == 3) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_4_BUSY_REG_OFFSET);
    } else if (clusterId == 4) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_5_BUSY_REG_OFFSET);
    }

    while (*busy_ptr == 1) {
    }
    return;
}

/* Offloads a void function pointer to the specified cluster's core 0 */
void offloadToCluster(void *function, uint8_t clusterId) {

    volatile void **snitchBootAddr =
        (volatile void **)(SOC_CTRL_BASE + CHIMERA_SNITCH_BOOT_ADDR_REG_OFFSET);

    *snitchBootAddr = function;

    uint32_t hartId = clusterId * 9 + 1;

    volatile uint32_t *interruptTarget = ((uint32_t *)CLINT_CTRL_BASE) + hartId;
    waitClusterBusy(clusterId);
    *interruptTarget = 1;
}

/* Busy waits for the return of a cluster, clears the return register, and
 * returns the return value */
uint32_t waitForCluster(uint8_t clusterId) {
    volatile int32_t *snitchReturnAddr;
    if (clusterId == 0) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_1_RETURN_REG_OFFSET);
    } else if (clusterId == 1) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_2_RETURN_REG_OFFSET);
    } else if (clusterId == 2) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_3_RETURN_REG_OFFSET);
    } else if (clusterId == 3) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_4_RETURN_REG_OFFSET);
    } else if (clusterId == 4) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_5_RETURN_REG_OFFSET);
    }

    while (*snitchReturnAddr == 0) {
    }

    uint32_t retVal = *snitchReturnAddr;
    *snitchReturnAddr = 0;

    return retVal;
}
