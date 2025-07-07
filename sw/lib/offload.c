// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

#include "soc_addr_map.h"
#include <chimera_addrmap.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

void setupInterruptHandler(void *handler) {
    volatile void **snitchTrapHandlerAddr =
        (volatile void **)(&chimera_addrmap.host.chimera_regs.snitch_intr_handler_addr);

    *snitchTrapHandlerAddr = handler;
}

void waitClusterBusy(uint8_t clusterId) {
    volatile int32_t *busy_ptr;
    busy_ptr = (volatile int32_t *)(&chimera_addrmap.host.chimera_regs.cluster_busy[clusterId]);

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
void setClusterClockGating(uint8_t clusterId, bool enable) {
    volatile uint32_t *regPtr =
        (volatile uint32_t *)chimera_addrmap.host.chimera_regs.cluster_clk_gate_en;

    setReg(regPtr, clusterId, enable);
}

/* Set Clock Gating on all clusters */
void setAllClusterClockGating(volatile uint8_t numRegs, bool enable) {
    volatile uint32_t *regPtr =
        (volatile uint32_t *)chimera_addrmap.host.chimera_regs.cluster_clk_gate_en;

    setAllRegs(regPtr, numRegs, enable);
}

/* Set Soft Reset on specified cluster */
void setClusterReset(uint8_t clusterId, bool enable) {
    volatile uint32_t *regPtr =
        (volatile uint32_t *)chimera_addrmap.host.chimera_regs.reset_cluster;

    setReg(regPtr, clusterId, enable);
}

/* Set Soft Reset on all clusters */
void setAllClusterReset(volatile uint8_t numRegs, bool enable) {
    volatile uint32_t *regPtr =
        (volatile uint32_t *)chimera_addrmap.host.chimera_regs.reset_cluster;

    setAllRegs(regPtr, numRegs, enable);
}

/* Set Bit on specified register  */
void setReg(volatile uint32_t *regPtr, uint8_t regIdx, bool enable) {

    if (regPtr == NULL) return;

    regPtr[regIdx] = enable;
}

/* Set Bit on all registers  */
void setAllRegs(volatile uint32_t *regPtr, uint8_t numRegs, bool enable) {

    if (regPtr == NULL) return;

    for (int i = 0; i < numRegs; i++) {
        regPtr[i] = enable;
    }
}

/* Offloads a void function pointer to the specified cluster's core 0 */
void offloadToCluster(void *function, uint8_t clusterId) {

    volatile void **snitchBootAddr =
        (volatile void **)(&chimera_addrmap.host.chimera_regs.snitch_boot_addr);

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
    snitchReturnAddr =
        (volatile int32_t *)(&chimera_addrmap.host.chimera_regs.snitch_cluster_return[clusterId]);

    while (*snitchReturnAddr == 0) {
    }

    uint32_t retVal = *snitchReturnAddr;
    *snitchReturnAddr = 0;

    return retVal;
}
