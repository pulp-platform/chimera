// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

#include "regs/soc_ctrl.h"
#include "soc_addr_map.h"
#include <stdint.h>

int main() {
    volatile uint8_t *regPtr = (volatile uint8_t *)SOC_CTRL_BASE;

    *(regPtr + CHIMERA_CLUSTER_0_CLK_GATE_EN_REG_OFFSET) = 1;
    *(regPtr + CHIMERA_CLUSTER_3_CLK_GATE_EN_REG_OFFSET) = 1;
    *(regPtr + CHIMERA_CLUSTER_4_CLK_GATE_EN_REG_OFFSET) = 1;

    while (1) {
    }

    return 0;
}
