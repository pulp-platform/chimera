# Copyright 2020 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

#include <soc_ctrl.h>
	
.global _start
_start:

	csrrc x0, mstatus, 10	
	
	li x5, 0
	li x6, 0
	li x7, 0
	li x8, 0
	li x9, 0
	li x10, 0
	li x11, 0
	li x12, 0
	li x13, 0
	li x14, 0
	li x15, 0
	li x16, 0
	li x17, 0
	li x18, 0
	li x19, 0
	li x20, 0
	li x21, 0
	li x22, 0
	li x23, 0
	li x24, 0
	li x25, 0
	li x26, 0
	li x27, 0
	li x28, 0
	li x29, 0
	li x30, 0
	li x31, 0
	
	call cluster_startup

	// Set trap vector
	la t0, _trap_handler_wrap
	csrrw x0, mtvec, t0
	
	wfi

run_from_reg:
	la t0, __chim_regs // CHIMERA REGS Base Addr, 0x3000_1000
	lw t0, 0(t0) // CHIMERA_SNITCH_BOOT_ADDR_REG_OFFSET
	jalr t0

exit:
	la t0, __chim_regs // CHIMERA REGS Base Addr
	sw t0, 4(t0) // CHIMERA_SNITCH_CLUSTER_1_RETURN_REG_OFFSET  // SCHEREMO: TODO: Demultiplex different clusters
	j _start
	
// This wraps the C trap handler to save the (integer-only) caller-save
// registers and perform a proper machine-mode exception return.
.align 4
_trap_handler_wrap:
	lui t6,0x2040
	li t5, 0
	sw t5, 40(t6)
    mret

.global trap_vector
.weak trap_vector
trap_vector:
    ret
