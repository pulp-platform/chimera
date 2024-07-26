/* =====================================================================
 * Title:        testClusterGating.c
 * Description:
 *
 * $Date:        27.06.2024
 *
 * ===================================================================== */
/*
 * Copyright (C) 2020 ETH Zurich and University of Bologna.
 *
 * Author: Moritz Scherer, ETH Zurich
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the License); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an AS IS BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "regs/soc_ctrl.h"
#include "soc_addr_map.h"
#include <stdint.h>

int main() {
    volatile uint8_t *regPtr = (volatile uint8_t *)SOC_CTRL_BASE;

    *(regPtr + CHIMERA_CLUSTER_1_CLK_GATE_EN_REG_OFFSET) = 1;
    *(regPtr + CHIMERA_CLUSTER_4_CLK_GATE_EN_REG_OFFSET) = 1;
    *(regPtr + CHIMERA_CLUSTER_5_CLK_GATE_EN_REG_OFFSET) = 1;

    while (1) {
    }

    return 0;
}
