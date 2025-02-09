// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

#ifndef _OFFLOAD_INCLUDE_GUARD_
#define _OFFLOAD_INCLUDE_GUARD_

#include <stdbool.h>
#include <stdint.h>

void setupInterruptHandler(void *handler);
void setClusterClockGating(uint8_t *regPtr, uint8_t clusterId, bool enable);
void setAllClusterClockGating(uint8_t *regPtr, bool enable);
void offloadToCluster(void *function, uint8_t hartId);
void waitClusterBusy(uint8_t clusterId);
uint32_t waitForCluster(uint8_t clusterId);

#endif
