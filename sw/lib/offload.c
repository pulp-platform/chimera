/* =====================================================================
 * Title:        offload.c
 * Description:  
 *
 * $Date:        23.07.2024        
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

void setupInterruptHandler(void* handler){
  volatile void** snitchTrapHandlerAddr = (volatile void**) (SOC_CTRL_BASE + CHIMERA_SNITCH_INTR_HANDLER_ADDR_REG_OFFSET);

  *snitchTrapHandlerAddr = handler;
}


/* Offloads a void function pointer to the specified cluster's core 0 */
void offloadToCluster(void* function, uint8_t clusterId){

  volatile void** snitchBootAddr = (volatile void**) (SOC_CTRL_BASE + CHIMERA_SNITCH_BOOT_ADDR_REG_OFFSET);
  
  *snitchBootAddr = function;

  uint32_t hartId = clusterId * 9 + 1;
  
  volatile uint32_t* interruptTarget = ((uint32_t*) CLINT_CTRL_BASE) + hartId;
  *interruptTarget = 1;
}

/* Busy waits for the return of a cluster, clears the return register, and returns the return value */
uint32_t waitForCluster(uint8_t clusterId){
  volatile int32_t* snitchReturnAddr;
  if (clusterId == 0){
    snitchReturnAddr = (volatile int32_t*) (SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_1_RETURN_REG_OFFSET);
  } else if(clusterId == 1) {
    snitchReturnAddr = (volatile int32_t*) (SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_2_RETURN_REG_OFFSET);
  } else if(clusterId == 2) {
    snitchReturnAddr = (volatile int32_t*) (SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_3_RETURN_REG_OFFSET);
  } else if(clusterId == 3) {
    snitchReturnAddr = (volatile int32_t*) (SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_4_RETURN_REG_OFFSET);
  } else if(clusterId == 4) {
    snitchReturnAddr = (volatile int32_t*) (SOC_CTRL_BASE + CHIMERA_SNITCH_CLUSTER_5_RETURN_REG_OFFSET);
  }
  
  while(*snitchReturnAddr == 0){
    
  }
  
  uint32_t retVal = *snitchReturnAddr;
  *snitchReturnAddr = 0;
  
  return retVal;
}
