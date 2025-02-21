// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Sergio Mazzola <smazzola@iis.ee.ethz.ch>

// Simple offload test to PULP Cluster 0. First set the boot address of all 8
// cluster cores to the desired one (the simple test function), then enables the
// fetch enable for all cores at the same time. All this is done through writes
// to the cluster's peripheral interconnect. Does not currently take care of the
// cluster return value.

#include "offload.h"
#include "soc_addr_map.h"
#include <regs/soc_ctrl.h>
#include <stdint.h>

#define TESTVAL_CLUSTER 0xdeadbeef

#define PERIPH_OFFSET            0x00200000

#define FETCH_EN_OFFSET          (PERIPH_OFFSET + 0x008)

#define BOOT_ADDR_CORE_0_OFFSET  (PERIPH_OFFSET + 0x040)
#define BOOT_ADDR_CORE_1_OFFSET  (PERIPH_OFFSET + 0x044)
#define BOOT_ADDR_CORE_2_OFFSET  (PERIPH_OFFSET + 0x048)
#define BOOT_ADDR_CORE_3_OFFSET  (PERIPH_OFFSET + 0x04C)
#define BOOT_ADDR_CORE_4_OFFSET  (PERIPH_OFFSET + 0x050)
#define BOOT_ADDR_CORE_5_OFFSET  (PERIPH_OFFSET + 0x054)
#define BOOT_ADDR_CORE_6_OFFSET  (PERIPH_OFFSET + 0x058)
#define BOOT_ADDR_CORE_7_OFFSET  (PERIPH_OFFSET + 0x05C)
#define BOOT_ADDR_CORE_8_OFFSET  (PERIPH_OFFSET + 0x060)
#define BOOT_ADDR_CORE_9_OFFSET  (PERIPH_OFFSET + 0x064)
#define BOOT_ADDR_CORE_10_OFFSET (PERIPH_OFFSET + 0x068)
#define BOOT_ADDR_CORE_11_OFFSET (PERIPH_OFFSET + 0x06C)
#define BOOT_ADDR_CORE_12_OFFSET (PERIPH_OFFSET + 0x070)
#define BOOT_ADDR_CORE_13_OFFSET (PERIPH_OFFSET + 0x074)
#define BOOT_ADDR_CORE_14_OFFSET (PERIPH_OFFSET + 0x078)
#define BOOT_ADDR_CORE_15_OFFSET (PERIPH_OFFSET + 0x07C)

int32_t test_cluster() {
    int32_t result;
    int32_t hart_id;

    asm volatile ("csrr %0, mhartid" : "=r"(hart_id)::);
    
    asm volatile (
        "li t0, %1\n"          // Load immediate value into t0
        "mv a0, t0\n"          // Move t0 into a0 (x10)
        "mv %0, a0\n"          // Move a0 into the output variable
        : "=r"(result)         // Output operand
        : "i"(TESTVAL_CLUSTER) // Input operand: immediate value
        : "t0", "a0"           // Clobbered registers
    );

    result = result + hart_id;

    return result;
}

int main() {
    int32_t hart_id;
    asm volatile ("csrr %0, mhartid" : "=r"(hart_id)::);

    // set boot address of all cores in cluster 0
    uint8_t *boot_addr_core_0_cluster_0 = CLUSTER_0_BASE + BOOT_ADDR_CORE_0_OFFSET;
    uint8_t *boot_addr_core_1_cluster_0 = CLUSTER_0_BASE + BOOT_ADDR_CORE_1_OFFSET;
    uint8_t *boot_addr_core_2_cluster_0 = CLUSTER_0_BASE + BOOT_ADDR_CORE_2_OFFSET;
    uint8_t *boot_addr_core_3_cluster_0 = CLUSTER_0_BASE + BOOT_ADDR_CORE_3_OFFSET;
    uint8_t *boot_addr_core_4_cluster_0 = CLUSTER_0_BASE + BOOT_ADDR_CORE_4_OFFSET;
    uint8_t *boot_addr_core_5_cluster_0 = CLUSTER_0_BASE + BOOT_ADDR_CORE_5_OFFSET;
    uint8_t *boot_addr_core_6_cluster_0 = CLUSTER_0_BASE + BOOT_ADDR_CORE_6_OFFSET;
    uint8_t *boot_addr_core_7_cluster_0 = CLUSTER_0_BASE + BOOT_ADDR_CORE_7_OFFSET;

    *((uint32_t*)boot_addr_core_0_cluster_0) = test_cluster;
    *((uint32_t*)boot_addr_core_1_cluster_0) = test_cluster;
    *((uint32_t*)boot_addr_core_2_cluster_0) = test_cluster;
    *((uint32_t*)boot_addr_core_3_cluster_0) = test_cluster;
    *((uint32_t*)boot_addr_core_4_cluster_0) = test_cluster;
    *((uint32_t*)boot_addr_core_5_cluster_0) = test_cluster;
    *((uint32_t*)boot_addr_core_6_cluster_0) = test_cluster;
    *((uint32_t*)boot_addr_core_7_cluster_0) = test_cluster;

    // enable fetch for all cores in cluster 0
    uint8_t *fetch_en_cluster_0 = CLUSTER_0_BASE + FETCH_EN_OFFSET;

    *((uint32_t*)fetch_en_cluster_0) = 0x00FF;
    
    // only the host hart executes this
    volatile int count = 100;
    if (hart_id == 0) {
        // delay loop
        asm volatile (
            "1: nop\n"
            "addi %0, %0, -1\n"
            "bnez %0, 1b\n"
            : "+r"(count) // Input and output operand
        );
    }
    return count;
}