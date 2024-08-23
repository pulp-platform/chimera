// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

#ifndef _OFFLOAD_INCLUDE_GUARD_
#define _OFFLOAD_INCLUDE_GUARD_

#include <stdint.h>

void setupInterruptHandler(void *handler);
void offloadToCluster(void *function, uint8_t hartId);
void waitClusterBusy(uint8_t clusterId);
uint32_t waitForCluster(uint8_t clusterId);

#endif
