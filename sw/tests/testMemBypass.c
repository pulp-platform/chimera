/* =====================================================================
 * Title:        testMemBypass.c
 * Description:
 *
 * $Date:        15.07.2024
 *
 * ===================================================================== */
/*
 * Copyright (C) 2020 ETH Zurich and University of Bologna.
 *
 * Author: Lorenzo Leone, ETH Zurich
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

#include <stdint.h>
#include "regs/soc_ctrl.h"
#include "offload.h"
#include "soc_addr_map.h"

//#define TOPLEVELREGION 0x30001000
#define REG_BASE       0x30001000
#define TESTVAL        0x050CCE55

static uint32_t* clintPointer = (uint32_t*) CLINT_CTRL_BASE;

void clusterTrapHandler(){
  uint8_t hartId;
  asm ("csrr %0, mhartid" : "=r" (hartId) ::);

  volatile uint32_t* interruptTarget = clintPointer + hartId;
  *interruptTarget = 0;
  return;
}

uint8_t readBypassReg(){
  return *((volatile uint8_t*) (SOC_CTRL_BASE + CHIMERA_WIDE_MEM_CLUSTER_BYPASS_REG_OFFSET));
}

void setBypassReg(uint8_t val){
  volatile uint8_t* regPtr;

  regPtr = (volatile uint8_t*) (SOC_CTRL_BASE + CHIMERA_WIDE_MEM_CLUSTER_BYPASS_REG_OFFSET);
  *regPtr = val;
  return;
}

int32_t testMemBypass(){
  return TESTVAL;
}

int main(){
  uint32_t retVal = 0;
  uint8_t  setVal = 1;

  // Test Reset value
  if (readBypassReg() != 0){
    retVal = 1;
    return retVal;
  }

  // Test register writability
  setBypassReg(setVal);

   if (readBypassReg() != setVal){
    retVal = 2;
    return retVal;
  }

  // Offload Cluster to use narrow/wide path
  setupInterruptHandler(clusterTrapHandler);
  offloadToCluster(testMemBypass, 1);
  retVal = waitForCluster(1);

  return  (retVal != (TESTVAL | 0x000000001));

}
