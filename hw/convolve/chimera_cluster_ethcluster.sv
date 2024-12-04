// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

module chimera_cluster_ethcluster
  import chimera_pkg::*;
  import cheshire_pkg::*;
#(
  parameter chimera_cfg_t Cfg = '0,

  parameter int unsigned NrCores           = 2,
  parameter type         narrow_in_req_t   = logic,
  parameter type         narrow_in_resp_t  = logic,
  parameter type         narrow_out_req_t  = logic,
  parameter type         narrow_out_resp_t = logic,
  parameter type         wide_out_req_t    = logic,
  parameter type         wide_out_resp_t   = logic
) (

  input  logic                                 soc_clk_i,
  input  logic                                 clu_clk_i,
  input  logic                                 rst_ni,
  input  logic                                 widemem_bypass_i,
  //-----------------------------
  // Interrupt ports
  //-----------------------------
  input  logic             [      NrCores-1:0] debug_req_i,
  input  logic             [      NrCores-1:0] meip_i,
  input  logic             [      NrCores-1:0] mtip_i,
  input  logic             [      NrCores-1:0] msip_i,
  //-----------------------------
  // Cluster base addressing
  //-----------------------------
  input  logic             [              9:0] hart_base_id_i,
  input  logic             [Cfg.ChsCfg.AddrWidth-1:0] cluster_base_addr_i,
  input  logic             [             31:0] boot_addr_i,
  //-----------------------------
  // Narrow AXI ports
  //-----------------------------
  input  narrow_in_req_t                       narrow_in_req_i,
  output narrow_in_resp_t                      narrow_in_resp_o,
  output narrow_out_req_t  [              1:0] narrow_out_req_o,
  input  narrow_out_resp_t [              1:0] narrow_out_resp_i,
  //-----------------------------
  //Wide AXI ports
  //-----------------------------
  output wide_out_req_t                        wide_out_req_o,
  input  wide_out_resp_t                       wide_out_resp_i
);

  `include "axi/typedef.svh"

  localparam int WideDataWidth = $bits(wide_out_req_o.w.data);

  localparam int WideMasterIdWidth = $bits(wide_out_req_o.aw.id);
  localparam int WideSlaveIdWidth = WideMasterIdWidth + $clog2(Cfg.ChsCfg.AxiExtNumWideMst) - 1;

  localparam int NarrowSlaveIdWidth = $bits(narrow_in_req_i.aw.id);
  localparam int NarrowMasterIdWidth = $bits(narrow_out_req_o[0].aw.id);

  typedef logic [Cfg.ChsCfg.AddrWidth-1:0] axi_addr_t;
  typedef logic [Cfg.ChsCfg.AxiUserWidth-1:0] axi_user_t;

  typedef logic [Cfg.ChsCfg.AxiDataWidth-1:0] axi_soc_data_narrow_t;
  typedef logic [Cfg.ChsCfg.AxiDataWidth/8-1:0] axi_soc_strb_narrow_t;

  typedef logic [ClusterDataWidth-1:0] axi_cluster_data_narrow_t;
  typedef logic [ClusterDataWidth/8-1:0] axi_cluster_strb_narrow_t;

  typedef logic [WideDataWidth-1:0] axi_cluster_data_wide_t;
  typedef logic [WideDataWidth/8-1:0] axi_cluster_strb_wide_t;

  typedef logic [ClusterNarrowAxiMstIdWidth-1:0] axi_cluster_mst_id_width_narrow_t;
  typedef logic [ClusterNarrowAxiMstIdWidth-1+2:0] axi_cluster_slv_id_width_narrow_t;

  typedef logic [NarrowMasterIdWidth-1:0] axi_soc_mst_id_width_narrow_t;
  typedef logic [NarrowSlaveIdWidth-1:0] axi_soc_slv_id_width_narrow_t;

  typedef logic [WideMasterIdWidth-1:0] axi_mst_id_width_wide_t;
  typedef logic [WideMasterIdWidth-1+2:0] axi_slv_id_width_wide_t;

  `AXI_TYPEDEF_ALL(axi_cluster_out_wide, axi_addr_t, axi_slv_id_width_wide_t,
                   axi_cluster_data_wide_t, axi_cluster_strb_wide_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_wide, axi_addr_t, axi_mst_id_width_wide_t,
                   axi_cluster_data_wide_t, axi_cluster_strb_wide_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_soc_out_narrow, axi_addr_t, axi_soc_slv_id_width_narrow_t,
                   axi_soc_data_narrow_t, axi_soc_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_soc_in_narrow, axi_addr_t, axi_soc_mst_id_width_narrow_t,
                   axi_soc_data_narrow_t, axi_soc_strb_narrow_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_cluster_out_narrow, axi_addr_t, axi_cluster_slv_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_narrow, axi_addr_t, axi_cluster_mst_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)

  `AXI_TYPEDEF_ALL(axi_cluster_out_narrow_socIW, axi_addr_t, axi_soc_mst_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_in_narrow_socIW, axi_addr_t, axi_soc_slv_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_user_t)

  // Cluster-side in- and out- narrow ports used in chimera adapter
  axi_cluster_in_narrow_req_t               clu_axi_adapter_slv_req;
  axi_cluster_in_narrow_resp_t              clu_axi_adapter_slv_resp;
  axi_cluster_out_narrow_req_t              clu_axi_adapter_mst_req;
  axi_cluster_out_narrow_resp_t             clu_axi_adapter_mst_resp;

  // Cluster-side in- and out- narrow ports used in narrow adapter
  axi_cluster_in_narrow_socIW_req_t         clu_axi_narrow_slv_req;
  axi_cluster_in_narrow_socIW_resp_t        clu_axi_narrow_slv_rsp;
  axi_cluster_out_narrow_socIW_req_t  [1:0] clu_axi_narrow_mst_req;
  axi_cluster_out_narrow_socIW_resp_t [1:0] clu_axi_narrow_mst_rsp;

  // Cluster-side out wide ports
  axi_cluster_out_wide_req_t                clu_axi_wide_mst_req;
  axi_cluster_out_wide_resp_t               clu_axi_wide_mst_resp;

  if (ClusterDataWidth != Cfg.ChsCfg.AxiDataWidth) begin : gen_narrow_adapter

    narrow_adapter #(
      .narrow_in_req_t  (axi_soc_out_narrow_req_t),
      .narrow_in_resp_t (axi_soc_out_narrow_resp_t),
      .narrow_out_req_t (axi_soc_in_narrow_req_t),
      .narrow_out_resp_t(axi_soc_in_narrow_resp_t),

      .clu_narrow_in_req_t  (axi_cluster_in_narrow_socIW_req_t),
      .clu_narrow_in_resp_t (axi_cluster_in_narrow_socIW_resp_t),
      .clu_narrow_out_req_t (axi_cluster_out_narrow_socIW_req_t),
      .clu_narrow_out_resp_t(axi_cluster_out_narrow_socIW_resp_t),

      .MstPorts(2),
      .SlvPorts(1)

    ) i_cluster_narrow_adapter (
      .soc_clk_i(soc_clk_i),
      .rst_ni,

      // SoC side narrow.
      .narrow_in_req_i  (narrow_in_req_i),
      .narrow_in_resp_o (narrow_in_resp_o),
      .narrow_out_req_o (narrow_out_req_o),
      .narrow_out_resp_i(narrow_out_resp_i),

      // Cluster side narrow
      .clu_narrow_in_req_o  (clu_axi_narrow_slv_req),
      .clu_narrow_in_resp_i (clu_axi_narrow_slv_rsp),
      .clu_narrow_out_req_i (clu_axi_narrow_mst_req),
      .clu_narrow_out_resp_o(clu_axi_narrow_mst_rsp)

    );

  end else begin : gen_skip_narrow_adapter  // if (ClusterDataWidth != Cfg.AxiDataWidth)

    assign clu_axi_narrow_slv_req = narrow_in_req_i;
    assign narrow_in_resp_o       = clu_axi_narrow_slv_rsp;
    assign narrow_out_req_o       = clu_axi_narrow_mst_req;
    assign clu_axi_narrow_mst_rsp = narrow_out_resp_i;

  end

  chimera_cluster_adapter #(
    .WidePassThroughRegionStart(Cfg.MemIslRegionStart),
    .WidePassThroughRegionEnd  (Cfg.MemIslRegionEnd),

    .narrow_in_req_t  (axi_cluster_in_narrow_socIW_req_t),
    .narrow_in_resp_t (axi_cluster_in_narrow_socIW_resp_t),
    .narrow_out_req_t (axi_cluster_out_narrow_socIW_req_t),
    .narrow_out_resp_t(axi_cluster_out_narrow_socIW_resp_t),

    .clu_narrow_in_req_t  (axi_cluster_in_narrow_req_t),
    .clu_narrow_in_resp_t (axi_cluster_in_narrow_resp_t),
    .clu_narrow_out_req_t (axi_cluster_out_narrow_req_t),
    .clu_narrow_out_resp_t(axi_cluster_out_narrow_resp_t),

    .wide_out_req_t (wide_out_req_t),
    .wide_out_resp_t(wide_out_resp_t),

    .clu_wide_out_req_t (axi_cluster_out_wide_req_t),
    .clu_wide_out_resp_t(axi_cluster_out_wide_resp_t)

  ) i_cluster_axi_adapter (
    .soc_clk_i(soc_clk_i),
    .clu_clk_i(clu_clk_i),
    .rst_ni,

    .narrow_in_req_i  (clu_axi_narrow_slv_req),
    .narrow_in_resp_o (clu_axi_narrow_slv_rsp),
    .narrow_out_req_o (clu_axi_narrow_mst_req),
    .narrow_out_resp_i(clu_axi_narrow_mst_rsp),

    .clu_narrow_in_req_o  (clu_axi_adapter_slv_req),
    .clu_narrow_in_resp_i (clu_axi_adapter_slv_resp),
    .clu_narrow_out_req_i (clu_axi_adapter_mst_req),
    .clu_narrow_out_resp_o(clu_axi_adapter_mst_resp),

    .wide_out_req_o     (wide_out_req_o),
    .wide_out_resp_i    (wide_out_resp_i),
    .clu_wide_out_req_i (clu_axi_wide_mst_req),
    .clu_wide_out_resp_o(clu_axi_wide_mst_resp),

    .wide_mem_bypass_mode_i(widemem_bypass_i)
  );


  ETHCluster_snitch_cluster_wrapper #(
  ) i_test_cluster (
    .clk_i(clu_clk_i),
    .rst_ni,

    .debug_req_i(debug_req_i),
    .meip_i     (meip_i),
    .mtip_i     (mtip_i),
    .msip_i     (msip_i),

    .hart_base_id_i     (hart_base_id_i),
    .cluster_base_addr_i(cluster_base_addr_i),
    .boot_addr_i        ({16'h0, boot_addr_i}),

    .narrow_in_req_i  (clu_axi_adapter_slv_req),
    .narrow_in_resp_o (clu_axi_adapter_slv_resp),
    .narrow_out_req_o (clu_axi_adapter_mst_req),
    .narrow_out_resp_i(clu_axi_adapter_mst_resp),
    .wide_in_req_i    ('0),
    .wide_in_resp_o   (),
    .wide_out_req_o   (clu_axi_wide_mst_req),
    .wide_out_resp_i  (clu_axi_wide_mst_resp)

  );
endmodule
