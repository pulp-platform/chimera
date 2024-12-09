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

// add snitch runtime for getting TCDM address
#include "kultest/snax-kul-cluster-gemmx-test.h"
#include "kultest/snax-kul-cluster-xdma-test.h"

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

    // offload gemm test function to kul cluster
    offloadToCluster(kul_cluster_gemmx_test, kul_clusterId);

    // wait for kul cluster to finish
    uint32_t retVal_gemmx = waitForCluster(kul_clusterId);

    // offload xdma test function to kul cluster
    offloadToCluster(kul_cluster_xdma_test, kul_clusterId);

    // wait for kul cluster to finish
    uint32_t retVal_xdma = waitForCluster(kul_clusterId);

    uint32_t retVal = (retVal_gemmx << 16) | retVal_xdma;
    return retVal;
}
