/* Copyright 2020 ETH Zurich and University of Bologna. */
/* Solderpad Hardware License, Version 0.51, see LICENSE for details. */
/* SPDX-License-Identifier: SHL-0.51 */
ENTRY(_start)

MEMORY {
       snitch_bootrom (rx) : ORIGIN = 0x30000000, LENGTH = 4K
}

SECTIONS
{
  . = 0x30000000;
  .text : { *(.text) }

  __snitch_bootrom = ORIGIN(snitch_bootrom);
  __chim_regs = 0x30001000;
}
