/* =====================================================================
 * Title:        testCluster.c
 * Description:
 *
 * $Date:        26.06.2024
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

#include <soc_addr_map.h>
#include <stdint.h>

#define CLUSTERMEMORYSTART CLUSTER_1_BASE
#define CLUSTERDISTANCE CLUSTER_2_BASE - CLUSTER_1_BASE
#define NUMCLUSTERS 5

#define TESTVAL 0x00E0D0C0

int main() {
  volatile int32_t *clusterMemPtr = (volatile int32_t *)CLUSTERMEMORYSTART;
  volatile int32_t result;

  uint8_t ret = 0;
  for (int i = 0; i < NUMCLUSTERS; i++) {
    *(clusterMemPtr) = TESTVAL;
    clusterMemPtr += CLUSTERDISTANCE / 4;
  }

  clusterMemPtr = (volatile int32_t *)CLUSTERMEMORYSTART;
  for (int i = 0; i < NUMCLUSTERS; i++) {
    result = *(clusterMemPtr);
    ret += (result == TESTVAL);
    clusterMemPtr += CLUSTERDISTANCE / 4;
  }

  if (ret == NUMCLUSTERS) {
    return 0;
  }

  return ret;
}
