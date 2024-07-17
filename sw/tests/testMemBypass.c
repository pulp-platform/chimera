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

#define TOPLEVELREGION 0x30001000

int main(){
  volatile uint8_t* regPtr = (volatile uint8_t*) TOPLEVELREGION;
  volatile uint8_t* bypassPtr = (volatile uint8_t*) (regPtr + CHIMERA_WIDE_MEM_CLUSTER_BYPASS_REG_OFFSET);

  uint8_t  ret = 0;
 
  // Check Reset value
    if(*bypassPtr != 0){
      ret += 1;
    }
  
  // Write a value inside the register
    *bypassPtr = 1;

  if(*bypassPtr != 1){
    ret += 1;
  }
  
  if(ret == 0){
    return 0;
  }
  
  return ret;
  
}
