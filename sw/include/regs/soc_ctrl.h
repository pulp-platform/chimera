// Generated register defines for chimera

// Copyright information found in source file:
// Copyright 2024 ETH Zurich and University of Bologna.

// Licensing information found in source file:
// 
// SPDX-License-Identifier: SHL-0.51

#ifndef _CHIMERA_REG_DEFS_
#define _CHIMERA_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define CHIMERA_PARAM_REG_WIDTH 32

// Set boot address for all snitch cores
#define CHIMERA_SNITCH_BOOT_ADDR_REG_OFFSET 0x0

// Set interrupt handler address for all snitch cores
#define CHIMERA_SNITCH_INTR_HANDLER_ADDR_REG_OFFSET 0x4

// Register to store return value of Snitch cluster 1
#define CHIMERA_SNITCH_CLUSTER_1_RETURN_REG_OFFSET 0x8

// Register to store return value of Snitch cluster 2
#define CHIMERA_SNITCH_CLUSTER_2_RETURN_REG_OFFSET 0xc

// Register to store return value of Snitch cluster 3
#define CHIMERA_SNITCH_CLUSTER_3_RETURN_REG_OFFSET 0x10

// Register to store return value of Snitch cluster 4
#define CHIMERA_SNITCH_CLUSTER_4_RETURN_REG_OFFSET 0x14

// Register to store return value of Snitch cluster 5
#define CHIMERA_SNITCH_CLUSTER_5_RETURN_REG_OFFSET 0x18

// Enable clock gate for cluster 1
#define CHIMERA_CLUSTER_1_CLK_GATE_EN_REG_OFFSET 0x1c
#define CHIMERA_CLUSTER_1_CLK_GATE_EN_CLUSTER_1_CLK_GATE_EN_BIT 0

// Enable clock gate for cluster 2
#define CHIMERA_CLUSTER_2_CLK_GATE_EN_REG_OFFSET 0x20
#define CHIMERA_CLUSTER_2_CLK_GATE_EN_CLUSTER_2_CLK_GATE_EN_BIT 0

// Enable clock gate for cluster 3
#define CHIMERA_CLUSTER_3_CLK_GATE_EN_REG_OFFSET 0x24
#define CHIMERA_CLUSTER_3_CLK_GATE_EN_CLUSTER_3_CLK_GATE_EN_BIT 0

// Enable clock gate for cluster 4
#define CHIMERA_CLUSTER_4_CLK_GATE_EN_REG_OFFSET 0x28
#define CHIMERA_CLUSTER_4_CLK_GATE_EN_CLUSTER_4_CLK_GATE_EN_BIT 0

// Enable clock gate for cluster 5
#define CHIMERA_CLUSTER_5_CLK_GATE_EN_REG_OFFSET 0x2c
#define CHIMERA_CLUSTER_5_CLK_GATE_EN_CLUSTER_5_CLK_GATE_EN_BIT 0

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _CHIMERA_REG_DEFS_
// End generated register defines for chimera