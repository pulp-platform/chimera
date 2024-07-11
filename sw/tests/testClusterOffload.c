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

#include <stdint.h>
#include <regs/soc_ctrl.h>

#define SOC_CTRL_BASEADDR 0x30001000
#define TESTVAL 0x50CCE55
#define FAILVAL 0xBADCAB1E

#define TARGETHARTID 1
#define IRQID 1

#define CLINTADDR 0x02040000
#define CLINTMSIP1OFFSET 0x28

static int32_t* clintPointer = (int32_t*) CLINTADDR;

int32_t testReturn(int32_t hartid){
  
  return TESTVAL;
}

int main(){
  
  volatile int32_t* snitchBootAddr = (volatile int32_t*) (SOC_CTRL_BASEADDR + CHIMERA_SNITCH_BOOT_ADDR_REG_OFFSET);
  volatile int32_t* snitchReturnAddr = (volatile int32_t*) (SOC_CTRL_BASEADDR + CHIMERA_SNITCH_CLUSTER_1_RETURN_REG_OFFSET);
  
  *snitchBootAddr = testReturn;

  *(clintPointer + CLINTMSIP1OFFSET/4) = 1;

  while(!*snitchReturnAddr){
    
  }
    
  return *snitchReturnAddr;
}
