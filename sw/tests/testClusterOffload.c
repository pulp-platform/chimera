/* =====================================================================
 * Title:        testClusterOffload.c
 * Description:  
 *
 * $Date:        28.06.2024        
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

// Simple offload test. Set the trap handler first, offload a function, retrieve return value from cluster. Does not currently take care of stack initialization and bss initialization on cluster.

#include <stdint.h>
#include <regs/soc_ctrl.h>
#include "soc_addr_map.h"
#include "offload.h"

#define TESTVAL 0x050CCE55

static uint32_t* clintPointer = (uint32_t*) CLINT_CTRL_BASE;

void clusterTrapHandler(){
  uint8_t hartId;
  asm ("csrr %0, mhartid" : "=r" (hartId) ::);

  volatile uint32_t* interruptTarget = clintPointer + hartId;
  *interruptTarget = 0;
  return;
}

int32_t testReturn(){
  return TESTVAL;
}

int main(){
  setupInterruptHandler(clusterTrapHandler);
  offloadToCluster(testReturn, 10);
  uint32_t retVal = waitForCluster(1);
    
  return (retVal != (TESTVAL | 0x000000001));
}
