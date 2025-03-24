// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

#include "regs/soc_ctrl.h"
#include "soc_addr_map.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

void setupInterruptHandler(void *handler) {
    volatile void **snitchTrapHandlerAddr =
        (volatile void **)(SOC_CTRL_BASE + CHIMERA_SNITCH_INTR_HANDLER_ADDR_REG_OFFSET);

    *snitchTrapHandlerAddr = handler;
}

void waitClusterBusy(uint8_t clusterId) {
    volatile int32_t *busy_ptr;

    if (clusterId == 0) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_0_BUSY_REG_OFFSET);
    } else if (clusterId == 1) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_1_BUSY_REG_OFFSET);
    } else if (clusterId == 2) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_2_BUSY_REG_OFFSET);
    } else if (clusterId == 3) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_3_BUSY_REG_OFFSET);
    } else if (clusterId == 4) {
        busy_ptr = (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_4_BUSY_REG_OFFSET);
    }

    while (*busy_ptr == 1) {
    }
    // TODO: temporary race condition fix
    for (int i = 0; i < 1000; i++) {
        // NOP
        asm volatile("addi x0, x0, 0\n" :::);
    }

    return;
}

/* Set Clock Gating on specified cluster */
void setClusterClockGating(volatile uint8_t *regPtr, uint8_t clusterId, bool enable) {

    if (regPtr == NULL) return;

    if (clusterId == 0) {
        *(regPtr + CHIMERA_CLUSTER_0_CLK_GATE_EN_REG_OFFSET) = enable;
    } else if (clusterId == 1) {
        *(regPtr + CHIMERA_CLUSTER_1_CLK_GATE_EN_REG_OFFSET) = enable;
    } else if (clusterId == 2) {
        *(regPtr + CHIMERA_CLUSTER_2_CLK_GATE_EN_REG_OFFSET) = enable;
    } else if (clusterId == 3) {
        *(regPtr + CHIMERA_CLUSTER_3_CLK_GATE_EN_REG_OFFSET) = enable;
    } else if (clusterId == 4) {
        *(regPtr + CHIMERA_CLUSTER_4_CLK_GATE_EN_REG_OFFSET) = enable;
    }
}

/* Set Clock Gating on all clusters */
void setAllClusterClockGating(volatile uint8_t *regPtr, bool enable) {

    if (regPtr == NULL) return;

    *(regPtr + CHIMERA_CLUSTER_0_CLK_GATE_EN_REG_OFFSET) = enable;
    *(regPtr + CHIMERA_CLUSTER_1_CLK_GATE_EN_REG_OFFSET) = enable;
    *(regPtr + CHIMERA_CLUSTER_2_CLK_GATE_EN_REG_OFFSET) = enable;
    *(regPtr + CHIMERA_CLUSTER_3_CLK_GATE_EN_REG_OFFSET) = enable;
    *(regPtr + CHIMERA_CLUSTER_4_CLK_GATE_EN_REG_OFFSET) = enable;
}

/* Set Soft Reset on specified cluster */
void setClusterReset(volatile uint8_t *regPtr, uint8_t clusterId, bool enable) {

    if (regPtr == NULL) return;

    if (clusterId == 0) {
        *(regPtr + CHIMERA_RESET_CLUSTER_0_REG_OFFSET) = enable;
    } else if (clusterId == 1) {
        *(regPtr + CHIMERA_RESET_CLUSTER_1_REG_OFFSET) = enable;
    } else if (clusterId == 2) {
        *(regPtr + CHIMERA_RESET_CLUSTER_2_REG_OFFSET) = enable;
    } else if (clusterId == 3) {
        *(regPtr + CHIMERA_RESET_CLUSTER_3_REG_OFFSET) = enable;
    } else if (clusterId == 4) {
        *(regPtr + CHIMERA_RESET_CLUSTER_4_REG_OFFSET) = enable;
    }
}

/* Set Soft Reset on all clusters */
void setAllClusterReset(volatile uint8_t *regPtr, bool enable) {

    if (regPtr == NULL) return;

    *(regPtr + CHIMERA_RESET_CLUSTER_0_REG_OFFSET) = enable;
    *(regPtr + CHIMERA_RESET_CLUSTER_1_REG_OFFSET) = enable;
    *(regPtr + CHIMERA_RESET_CLUSTER_2_REG_OFFSET) = enable;
    *(regPtr + CHIMERA_RESET_CLUSTER_3_REG_OFFSET) = enable;
    *(regPtr + CHIMERA_RESET_CLUSTER_4_REG_OFFSET) = enable;
}

/* Offloads a void function pointer to the specified cluster's core 0 */
void offloadToCluster(void *function, uint8_t clusterId) {

    volatile void **snitchBootAddr =
        (volatile void **)(SOC_CTRL_BASE + CHIMERA_SNITCH_BOOT_ADDR_REG_OFFSET);

    *snitchBootAddr = function;

    uint32_t hartId = 1;
    for (uint32_t i = 0; i < clusterId; i++) {
        hartId += _chimera_numCores[i];
    }

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
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_0_RETURN_REG_OFFSET);
    } else if (clusterId == 1) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_1_RETURN_REG_OFFSET);
    } else if (clusterId == 2) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_2_RETURN_REG_OFFSET);
    } else if (clusterId == 3) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_3_RETURN_REG_OFFSET);
    } else if (clusterId == 4) {
        snitchReturnAddr =
            (volatile int32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_4_RETURN_REG_OFFSET);
    }

    while (*snitchReturnAddr == 0) {
    }

    uint32_t retVal = *snitchReturnAddr;
    *snitchReturnAddr = 0;

    return retVal;
}
