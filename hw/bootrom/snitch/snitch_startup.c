// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Lorenzo Leone  <lleone@iis.ee.ethz.ch>

#include <stdint.h>

// SoC-control register absolute addresses come straight from the SystemRDL
// single source of truth (peakrdl raw-header -> .generated/chimera_addrmap_raw.h,
// `make rdl`). The per-cluster core count / cluster count come from the
// generated snitch cluster config. All resolved via -I .generated (see chimera.mk).
#include "chimera_addrmap_raw.h"
#include "snitch_cluster_addrmap.h"
#include "snitch_cluster_cfg.h"

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

// Snitch harts are numbered 1..(SNRT_CLUSTER_NUM * CFG_CLUSTER_NR_CORES); the
// host is hart 0. Only a cluster's first hart drives that cluster's SoC-control
// registers. Returns 1 and sets *clusterId when hartId is such a first hart.
static inline int chimera_cluster_of_hart(uint8_t hartId, uint32_t *clusterId) {
    if (hartId < 1) {
        return 0;
    }
    uint32_t idx = (uint32_t)hartId - 1u;
    if (idx % CFG_CLUSTER_NR_CORES != 0) {
        return 0;
    }
    *clusterId = idx / CFG_CLUSTER_NR_CORES;
    return (*clusterId < SNRT_CLUSTER_NUM);
}

void cluster_startup() {
    set_csr(mie, MIP_MSIP);
    set_csr(mstatus, MSTATUS_MIE); // set M global interrupt enable
    return;
}

void cluster_return(uint32_t ret) {
    uint32_t retVal = ret | 0x000000001;

    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    uint32_t clusterId;
    if (chimera_cluster_of_hart(hartId, &clusterId)) {
        *((volatile uint32_t *)CHIMERA_ADDRMAP_SOC_CTRL_SNITCH_CLUSTER_RETURN_BASE_ADDR(clusterId)) =
            retVal;
    }

    return;
}

void clean_busy() {
    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    uint32_t clusterId;
    if (chimera_cluster_of_hart(hartId, &clusterId)) {
        *((volatile uint32_t *)CHIMERA_ADDRMAP_SOC_CTRL_CLUSTER_BUSY_BASE_ADDR(clusterId)) = 0;
    }

    return;
}

void set_busy() {
    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    uint32_t clusterId;
    if (chimera_cluster_of_hart(hartId, &clusterId)) {
        *((volatile uint32_t *)CHIMERA_ADDRMAP_SOC_CTRL_CLUSTER_BUSY_BASE_ADDR(clusterId)) = 1;
    }

    return;
}
