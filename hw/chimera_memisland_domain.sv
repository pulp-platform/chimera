// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

module chimera_memisland_domain
  import chimera_pkg::*;
  import cheshire_pkg::*;
#(
  parameter chimera_cfg_t Cfg              = '0,
  parameter int unsigned  NumWideMst       = '0,
  parameter type          axi_narrow_req_t = logic,
  parameter type          axi_narrow_rsp_t = logic,
  parameter type          axi_wide_req_t   = logic,
  parameter type          axi_wide_rsp_t   = logic
) (
  input  logic                             clk_i,
  input  logic                             rst_ni,
  input  axi_narrow_req_t                  axi_narrow_req_i,
  output axi_narrow_rsp_t                  axi_narrow_rsp_o,
  input  axi_wide_req_t   [NumWideMst-1:0] axi_wide_req_i,
  output axi_wide_rsp_t   [NumWideMst-1:0] axi_wide_rsp_o
);

  `include "axi/typedef.svh"

  // Define needed parameters
  localparam int unsigned AxiSlvIdWidth = $bits(axi_narrow_req_i.aw.id);
  localparam int unsigned WideSlaveIdWidth = $clog2(Cfg.MemIslWidePorts);
  localparam int unsigned WideDataWidth = Cfg.ChsCfg.AxiDataWidth * Cfg.MemIslNarrowToWideFactor;

  axi_narrow_req_t axi_memory_island_amo_req;
  axi_narrow_rsp_t axi_memory_island_amo_rsp;

  axi_narrow_req_t axi_memory_island_amo_req_cut;
  axi_narrow_rsp_t axi_memory_island_amo_rsp_cut;

  // Define AXI TYPES
  typedef logic [Cfg.ChsCfg.AddrWidth-1:0] axi_narrow_addr_t;
  typedef logic [AxiSlvIdWidth-1:0] axi_narrow_slv_id_t;
  typedef logic [Cfg.ChsCfg.AxiDataWidth-1:0] axi_narrow_data_t;
  typedef logic [Cfg.ChsCfg.AxiDataWidth/8-1:0] axi_narrow_strb_t;
  typedef logic [Cfg.ChsCfg.AxiUserWidth-1:0] axi_narrow_user_t;

  `AXI_TYPEDEF_ALL(axi_atomic_narrow, axi_narrow_addr_t, axi_narrow_slv_id_t, axi_narrow_data_t,
                   axi_narrow_strb_t, axi_narrow_user_t)


  axi_riscv_atomics_structs #(
    .AxiAddrWidth   (Cfg.ChsCfg.AddrWidth),
    .AxiDataWidth   (Cfg.ChsCfg.AxiDataWidth),
    .AxiIdWidth     (AxiSlvIdWidth),
    .AxiUserWidth   (Cfg.ChsCfg.AxiUserWidth),
    .AxiMaxReadTxns (Cfg.ChsCfg.LlcMaxReadTxns),
    .AxiMaxWriteTxns(Cfg.ChsCfg.LlcMaxWriteTxns),
    .AxiUserAsId    (1),
    .AxiUserIdMsb   (Cfg.ChsCfg.AxiUserAmoMsb),
    .AxiUserIdLsb   (Cfg.ChsCfg.AxiUserAmoLsb),
    .RiscvWordWidth (riscv::XLEN),
    .NAxiCuts       (Cfg.ChsCfg.LlcAmoNumCuts),
    .axi_req_t      (axi_narrow_req_t),
    .axi_rsp_t      (axi_narrow_rsp_t)
  ) i_memory_island_atomics (
    .clk_i        (clk_i),
    .rst_ni,
    .axi_slv_req_i(axi_narrow_req_i),
    .axi_slv_rsp_o(axi_narrow_rsp_o),
    .axi_mst_req_o(axi_memory_island_amo_req),
    .axi_mst_rsp_i(axi_memory_island_amo_rsp)
  );

  // -----------------------------------------------------------------------
  // | AXI CUT to break all combinatorial opaths betwen inputs and outputs |
  // -----------------------------------------------------------------------
  axi_cut #(
    .Bypass    (1'b0),
    .aw_chan_t (axi_atomic_narrow_aw_chan_t),
    .w_chan_t  (axi_atomic_narrow_w_chan_t),
    .b_chan_t  (axi_atomic_narrow_b_chan_t),
    .ar_chan_t (axi_atomic_narrow_ar_chan_t),
    .r_chan_t  (axi_atomic_narrow_r_chan_t),
    .axi_req_t (axi_atomic_narrow_req_t),
    .axi_resp_t(axi_atomic_narrow_resp_t)
  ) i_axi_atomic_cut (
    .clk_i     (clk_i),
    .rst_ni,
    .slv_req_i (axi_memory_island_amo_req),
    .slv_resp_o(axi_memory_island_amo_rsp),
    .mst_req_o (axi_memory_island_amo_req_cut),
    .mst_resp_i(axi_memory_island_amo_rsp_cut)
  );

  axi_memory_island_wrap #(
    .AddrWidth       (Cfg.ChsCfg.AddrWidth),
    .NarrowDataWidth (Cfg.ChsCfg.AxiDataWidth),
    .WideDataWidth   (WideDataWidth),
    .AxiNarrowIdWidth(AxiSlvIdWidth),
    .AxiWideIdWidth  (WideSlaveIdWidth),
    .axi_narrow_req_t(axi_narrow_req_t),
    .axi_narrow_rsp_t(axi_narrow_rsp_t),
    .axi_wide_req_t  (axi_wide_req_t),
    .axi_wide_rsp_t  (axi_wide_rsp_t),
    .NumNarrowReq    (Cfg.MemIslNarrowPorts),
    .NumWideReq      (Cfg.MemIslWidePorts),
    .NumWideBanks    (Cfg.MemIslNumWideBanks),
    .NarrowExtraBF   (1),
    .WordsPerBank    (Cfg.MemIslWordsPerBank)
  ) i_memory_island (
    .clk_i           (clk_i),
    .rst_ni,
    .axi_narrow_req_i(axi_memory_island_amo_req_cut),
    .axi_narrow_rsp_o(axi_memory_island_amo_rsp_cut),
    // SCHEREMO: TODO: Demux wide accesses to go over narrow ports iff address not in memory island range
    .axi_wide_req_i  (axi_wide_req_i),
    .axi_wide_rsp_o  (axi_wide_rsp_o)
  );

endmodule : chimera_memisland_domain
