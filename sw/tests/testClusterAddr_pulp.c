// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Sergio Mazzola <smazzola@iis.ee.ethz.ch>

// Simple addressability test which writes and subsequently reads a value
// in the first address mapped to the PULP Cluster 0 (i.e., the first
// TCDM address)

#include "offload.h"
#include "soc_addr_map.h"
#include <regs/soc_ctrl.h>
#include <stdint.h>

#define TESTVAL_CLUSTER 0xdeadbeef

int main() {
    uint8_t *base_addr_tcdm_cluster_0 = CLUSTER_0_BASE;

    *((uint32_t*)base_addr_tcdm_cluster_0) = TESTVAL_CLUSTER;
    
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");
    asm volatile ("nop");

    uint32_t result = *((uint32_t*)base_addr_tcdm_cluster_0);
    if (result == TESTVAL_CLUSTER) {
        return 0;
    } else {
        return 1;
    }
}