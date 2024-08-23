// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

#ifndef _SOC_ADDR_MAP_INCLUDE_GUARD_
#define _SOC_ADDR_MAP_INCLUDE_GUARD_

#include <stdint.h>

#define CLINT_CTRL_BASE 0x02040000

#define SOC_CTRL_BASE 0x30001000

#define CLUSTER_0_BASE 0x40000000
#define CLUSTER_1_BASE 0x40200000
#define CLUSTER_2_BASE 0x40400000
#define CLUSTER_3_BASE 0x40600000
#define CLUSTER_4_BASE 0x40800000

#define CLUSTER_0_NUMCORES 9
#define CLUSTER_1_NUMCORES 9
#define CLUSTER_2_NUMCORES 9
#define CLUSTER_3_NUMCORES 9
#define CLUSTER_4_NUMCORES 9

static uint8_t _chimera_numCores[] = {CLUSTER_0_NUMCORES, CLUSTER_1_NUMCORES, CLUSTER_2_NUMCORES,
                                      CLUSTER_3_NUMCORES, CLUSTER_4_NUMCORES};
#define _chimera_numClusters 5

#define CHIMERA_PADFRAME_BASE_ADDRESS 0x30002000
#define FLL_BASE_ADDR 0x30003000

#endif
