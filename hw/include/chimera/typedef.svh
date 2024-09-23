// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

`ifndef CHIMERA_TYPEDEF_SVH_
`define CHIMERA_TYPEDEF_SVH_

`include "axi/typedef.svh"
`include "register_interface/typedef.svh"
`include "cheshire/typedef.svh"

`define CHIMERA_TYPEDEF_MEMORYISLAND_WIDE(__prefix, __cfg) \
  localparam type __prefix``addr_t = logic [__cfg.ChsCfg.AddrWidth-1:0]; \
  localparam int wideDataWidth = __cfg.ChsCfg.AxiDataWidth*__cfg.MemIslNarrowToWideFactor; \
  localparam type __prefix``_axi_data_t    = logic [wideDataWidth   -1:0]; \
  localparam type __prefix``_axi_strb_t    = logic [wideDataWidth/8 -1:0]; \
  localparam type __prefix``_axi_user_t    = logic [__cfg.ChsCfg.AxiUserWidth   -1:0]; \
  localparam type __prefix``_axi_mst_id_t  = logic [__cfg.MemIslAxiMstIdWidth-1:0]; \
  localparam type __prefix``_axi_slv_id_t  = logic [__cfg.MemIslAxiMstIdWidth + $clog2(__cfg.MemIslWidePorts)-1:0]; \
  `CHESHIRE_TYPEDEF_AXI_CT(__prefix``_axi_mst, __prefix``addr_t, \
      __prefix``_axi_mst_id_t, __prefix``_axi_data_t, __prefix``_axi_strb_t, __prefix``_axi_user_t) \
  `CHESHIRE_TYPEDEF_AXI_CT(__prefix``_axi_slv, __prefix``addr_t, \
      __prefix``_axi_slv_id_t, __prefix``_axi_data_t, __prefix``_axi_strb_t, __prefix``_axi_user_t) \

// Note that the prefix does *not* include a leading underscore.
`define CHIMERA_TYPEDEF_ALL(__prefix, __cfg) \
  `CHIMERA_TYPEDEF_MEMORYISLAND_WIDE(mem_isl_wide, __cfg)

`endif
