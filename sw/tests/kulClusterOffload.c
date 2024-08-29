// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Xiaoling Yi <xiaoling.yi@esat.kuleuven.be>

// Offload `kul_cluster_sw_test` test function to KUL cluster.

#include "offload.h"
#include "soc_addr_map.h"
#include <regs/soc_ctrl.h>
#include <stdint.h>

static uint32_t *clintPointer = (uint32_t *)CLINT_CTRL_BASE;

void clusterTrapHandler() {
    uint8_t hartId;
    asm("csrr %0, mhartid" : "=r"(hartId)::);

    volatile uint32_t *interruptTarget = clintPointer + hartId;
    *interruptTarget = 0;
    return;
}

int main() {
    uint8_t kul_clusterId = 3;

    setupInterruptHandler(clusterTrapHandler);

    // set the stack pointer?

    // offload test function to kul cluster
    offloadToCluster(kul_cluster_sw_test, kul_clusterId);

    // wait fro kul cluster to finish
    uint32_t retVal = waitForCluster(kul_clusterId);

    return retVal;
}
