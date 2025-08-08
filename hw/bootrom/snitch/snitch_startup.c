// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Lorenzo Leone  <lleone@iis.ee.ethz.ch>

#include <stdint.h>
#include <regs/soc_ctrl.h>
#include <soc_addr_map.h>

#define set_csr(reg, bit) \
    ({ \
        unsigned long __tmp; \
        if (__builtin_constant_p(bit) && (unsigned long)(bit) < 32) \
            asm volatile("csrrs %0, " #reg ", %1" : "=r"(__tmp) : "i"(bit)); \
        else \
            asm volatile("csrrs %0, " #reg ", %1" : "=r"(__tmp) : "r"(bit)); \
        __tmp; \
    })

#define IRQ_M_SOFT 3

#define MSTATUS_MIE 0x00000008
#define MIP_MSIP (1 << IRQ_M_SOFT)

void cluster_startup() {
    set_csr(mie, MIP_MSIP);
    set_csr(mstatus, MSTATUS_MIE); // set M global interrupt enable
    return;
}

void cluster_return(uint32_t ret) {

    uint32_t retVal = ret | 0x000000001;

    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    switch (hartId) {

    case 1:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_0_RETURN_REG_OFFSET)) =
            retVal;
        break;
    case 1 + CLUSTER_0_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_1_RETURN_REG_OFFSET)) =
            retVal;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_2_RETURN_REG_OFFSET)) =
            retVal;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES + CLUSTER_2_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_3_RETURN_REG_OFFSET)) =
            retVal;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES + CLUSTER_2_NUMCORES + CLUSTER_3_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_4_RETURN_REG_OFFSET)) =
            retVal;
        break;
    }

    return;
}

void clean_busy() {

    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    switch (hartId) {

    case 1:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_0_BUSY_REG_OFFSET)) = 0;
        break;
    case 1 + CLUSTER_0_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_1_BUSY_REG_OFFSET)) = 0;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_2_BUSY_REG_OFFSET)) = 0;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES + CLUSTER_2_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_3_BUSY_REG_OFFSET)) = 0;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES + CLUSTER_2_NUMCORES + CLUSTER_3_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_4_BUSY_REG_OFFSET)) = 0;
        break;
    }

    return;
}

void set_busy() {

    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    switch (hartId) {

    case 1:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_0_BUSY_REG_OFFSET)) = 1;
        break;
    case 1 + CLUSTER_0_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_1_BUSY_REG_OFFSET)) = 1;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_2_BUSY_REG_OFFSET)) = 1;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES + CLUSTER_2_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_3_BUSY_REG_OFFSET)) = 1;
        break;
    case 1 + CLUSTER_0_NUMCORES + CLUSTER_1_NUMCORES + CLUSTER_2_NUMCORES + CLUSTER_3_NUMCORES:
        *((volatile uint32_t *)(SOC_CTRL_BASE + CHIMERA_CLUSTER_4_BUSY_REG_OFFSET)) = 1;
        break;
    }

    return;
}
