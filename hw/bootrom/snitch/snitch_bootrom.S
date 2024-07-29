// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

#include <soc_ctrl.h>

.global _start
_start:

	csrrc x0, mstatus, 10
	call cluster_startup
	// Set trap vector
	la t0, _trap_handler_initial
	csrrw x0, mtvec, t0

_rerun:
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

	wfi

run_from_reg:
	la t0, __chim_regs // CHIMERA REGS Base Addr, 0x3000_1000
	lw t0, CHIMERA_SNITCH_BOOT_ADDR_REG_OFFSET(t0) // CHIMERA_SNITCH_BOOT_ADDR_REG_OFFSET
	jalr t0 // Register a0 will hold return value

_return:
	call cluster_return // By calling immediately after return, register contents in a0 are passed as the first argument

_exit:
	j _rerun

.align 4
_trap_handler_initial:
	la t0, __chim_regs // CHIMERA REGS Base Addr
	lw t0, CHIMERA_SNITCH_INTR_HANDLER_ADDR_REG_OFFSET(t0)
	jalr t0
	mret
