// Copyright 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Viviane Potocnik <vivianep@iis.ee.ethz.ch>

#include "regs/soc_ctrl.h"
#include "soc_addr_map.h"
#include "offload.h"
#include <stdint.h>

int main() {
    volatile uint8_t *regPtr = (volatile uint8_t *)SOC_CTRL_BASE;

    setAllClusterReset(regPtr, 0);
    setClusterClockGating(regPtr, 0, 1);
    setClusterClockGating(regPtr, 3, 1);
    setClusterClockGating(regPtr, 4, 1);

    while (1) {
    }

    return 0;
}
