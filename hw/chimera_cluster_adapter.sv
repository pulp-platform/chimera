// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

// Wraps a cluster's AXI ports with AXI CDCs on all narrow and wide ports,
// and converts axi id widths to match; takes care of demux wide requests
// to memory island / narrow crossbar

module chimera_cluster_adapter #(
  // Start address of Memory Island
  parameter int WidePassThroughRegionStart = '0,
  // End address of Memory Island
  parameter int WidePassThroughRegionEnd   = '0,

  parameter type narrow_in_req_t   = logic,
  parameter type narrow_in_resp_t  = logic,
  parameter type narrow_out_req_t  = logic,
  parameter type narrow_out_resp_t = logic,
  parameter type wide_out_req_t    = logic,
  parameter type wide_out_resp_t   = logic,

  parameter type clu_narrow_in_req_t   = logic,
  parameter type clu_narrow_in_resp_t  = logic,
  parameter type clu_narrow_out_req_t  = logic,
  parameter type clu_narrow_out_resp_t = logic,
  parameter type clu_wide_out_req_t    = logic,
  parameter type clu_wide_out_resp_t   = logic

) (
  input  logic                       soc_clk_i,
  input  logic                       clu_clk_i,
  input  logic                       rst_ni,
  // From SOC
  input  narrow_in_req_t             narrow_in_req_i,
  output narrow_in_resp_t            narrow_in_resp_o,
  output narrow_out_req_t      [1:0] narrow_out_req_o,
  input  narrow_out_resp_t     [1:0] narrow_out_resp_i,
  output wide_out_req_t              wide_out_req_o,
  input  wide_out_resp_t             wide_out_resp_i,
  // To Cluster
  output clu_narrow_in_req_t         clu_narrow_in_req_o,
  input  clu_narrow_in_resp_t        clu_narrow_in_resp_i,
  input  clu_narrow_out_req_t        clu_narrow_out_req_i,
  output clu_narrow_out_resp_t       clu_narrow_out_resp_o,
  input  clu_wide_out_req_t          clu_wide_out_req_i,
  output clu_wide_out_resp_t         clu_wide_out_resp_o,
  // Testing
  input  logic                       wide_mem_bypass_mode_i
);

  `include "axi/typedef.svh"

  // SCHEREMO: Define AXI helper types for downstream iw/dw conversion

  localparam int WideDataWidth = $bits(wide_out_req_o.w.data);
  localparam int NarrowDataWidth = $bits(narrow_out_req_o[0].w.data);
  localparam int AddrWidth = $bits(narrow_out_req_o[0].aw.addr);
  localparam int UserWidth = $bits(narrow_out_req_o[0].aw.user);

  localparam int ClusterNarrowMasterIdWidth = $bits(clu_narrow_out_req_i.aw.id);
  localparam int ClusterNarrowSlaveIdWidth = $bits(clu_narrow_in_req_o.aw.id);

  localparam int SocNarrowMasterIdWidth = $bits(narrow_out_req_o[0].aw.id);
  localparam int SocNarrowSlaveIdWidth = $bits(narrow_in_req_i.aw.id);
  localparam int SocWideMasterIdWidth = $bits(wide_out_req_o.aw.id);

  typedef logic [UserWidth-1:0] axi_user_width_t;
  typedef logic [AddrWidth-1:0] axi_addr_width_t;

  typedef logic [NarrowDataWidth-1:0] axi_narrow_data_width_t;
  typedef logic [NarrowDataWidth/8-1:0] axi_narrow_strb_width_t;

  typedef logic [WideDataWidth-1:0] axi_wide_data_width_t;
  typedef logic [WideDataWidth/8-1:0] axi_wide_strb_width_t;

  typedef logic [SocNarrowMasterIdWidth-1:0] axi_soc_narrow_mst_id_width_t;
  typedef logic [SocNarrowSlaveIdWidth-1:0] axi_soc_narrow_slv_id_width_t;

  typedef logic [SocWideMasterIdWidth-1:0] axi_soc_wide_mst_id_width_t;

  `AXI_TYPEDEF_ALL(axi_wide_clu_out, axi_addr_width_t, axi_soc_wide_mst_id_width_t,
                   axi_wide_data_width_t, axi_wide_strb_width_t, axi_user_width_t)

  `AXI_TYPEDEF_ALL(axi_narrow_soc_in, axi_addr_width_t, axi_soc_narrow_slv_id_width_t,
                   axi_narrow_data_width_t, axi_narrow_strb_width_t, axi_user_width_t)

  `AXI_TYPEDEF_ALL(axi_narrow_soc_out, axi_addr_width_t, axi_soc_narrow_mst_id_width_t,
                   axi_narrow_data_width_t, axi_narrow_strb_width_t, axi_user_width_t)

  `AXI_TYPEDEF_ALL(axi_wide_clu_wide_to_narrow, axi_addr_width_t, axi_soc_narrow_mst_id_width_t,
                   axi_wide_data_width_t, axi_wide_strb_width_t, axi_user_width_t)

  // Direct mst outputs of cluster -> has extra id bits on mst, gets iw converted

  clu_narrow_out_req_t  axi_from_cluster_narrow_iwc_req;
  clu_narrow_out_resp_t axi_from_cluster_narrow_iwc_resp;
  clu_wide_out_req_t    axi_from_cluster_wide_iwc_req;
  clu_wide_out_resp_t   axi_from_cluster_wide_iwc_resp;

  // Id width adapted mst outputs of cluster

  narrow_out_req_t      axi_from_cluster_narrow_req;
  narrow_out_resp_t     axi_from_cluster_narrow_resp;
  wide_out_req_t        axi_from_cluster_wide_req;
  wide_out_resp_t       axi_from_cluster_wide_resp;

  // Wide mst is demuxed to memory island and rest of SoC

  wide_out_req_t
      axi_from_cluster_wide_premux_req,
      axi_from_cluster_wide_memisl_req,
      axi_from_cluster_wide_to_narrow_req;

  wide_out_resp_t
      axi_from_cluster_wide_premux_resp,
      axi_from_cluster_wide_memisl_resp,
      axi_from_cluster_wide_to_narrow_resp;

  // Rest of SoC is width converted from wide to narrow

  axi_wide_clu_wide_to_narrow_req_t  axi_from_cluster_wide_to_narrow_iwc_req;
  axi_wide_clu_wide_to_narrow_resp_t axi_from_cluster_wide_to_narrow_iwc_resp;

  // Direct slv ports from SoC crossbar

  narrow_in_resp_t                   axi_to_cluster_narrow_resp;
  narrow_in_req_t                    axi_to_cluster_narrow_req;

  assign axi_from_cluster_narrow_iwc_req   = clu_narrow_out_req_i;
  assign clu_narrow_out_resp_o             = axi_from_cluster_narrow_iwc_resp;

  assign wide_out_req_o                    = axi_from_cluster_wide_memisl_req;
  assign axi_from_cluster_wide_memisl_resp = wide_out_resp_i;

  assign axi_from_cluster_wide_iwc_req     = clu_wide_out_req_i;
  assign clu_wide_out_resp_o               = axi_from_cluster_wide_iwc_resp;


  // WIDE-TO-NARROW CONVERSION
  // Catch requests over the wide port which do not go to the memory island; reroute them over the narrow AXI bus.
  // For testing purposes, when bypass_mode is asserted, wide requests must be routed over the narrow AXI bus

  logic ar_wide_sel, aw_wide_sel;

  always_comb begin
    if (wide_mem_bypass_mode_i) begin
      ar_wide_sel = '0;
      aw_wide_sel = '0;
    end else begin
      ar_wide_sel = (axi_from_cluster_wide_premux_req.ar.addr >= WidePassThroughRegionStart) &&
                    (axi_from_cluster_wide_premux_req.ar.addr < WidePassThroughRegionEnd);
      aw_wide_sel = (axi_from_cluster_wide_premux_req.aw.addr >= WidePassThroughRegionStart) &&
                    (axi_from_cluster_wide_premux_req.aw.addr < WidePassThroughRegionEnd);
    end
  end

  // SoC side wide demux for bypasses

  axi_demux_simple #(
    .AxiIdWidth (SocWideMasterIdWidth),
    .AtopSupport(0),
    .axi_req_t  (wide_out_req_t),
    .axi_resp_t (wide_out_resp_t),
    .NoMstPorts (2),
    .MaxTrans   (2),
    .AxiLookBits(SocWideMasterIdWidth),
    .UniqueIds  ('1)
  ) i_wide_demux (
    .clk_i          (soc_clk_i),
    .rst_ni,
    .test_i         ('0),
    .slv_req_i      (axi_from_cluster_wide_premux_req),
    .slv_aw_select_i(aw_wide_sel),
    .slv_ar_select_i(ar_wide_sel),
    .slv_resp_o     (axi_from_cluster_wide_premux_resp),
    .mst_reqs_o     ({axi_from_cluster_wide_memisl_req, axi_from_cluster_wide_to_narrow_req}),
    .mst_resps_i    ({axi_from_cluster_wide_memisl_resp, axi_from_cluster_wide_to_narrow_resp})
  );

  // SoC side Wide-to-narrow ID width converter for bypasses

  axi_iw_converter #(
    .AxiSlvPortIdWidth     (SocWideMasterIdWidth),
    .AxiMstPortIdWidth     (SocNarrowMasterIdWidth),
    .AxiSlvPortMaxUniqIds  (1),
    .AxiSlvPortMaxTxnsPerId(1),
    .AxiSlvPortMaxTxns     (2),
    .AxiMstPortMaxUniqIds  (2),
    .AxiMstPortMaxTxnsPerId(2),
    .AxiAddrWidth          (AddrWidth),
    .AxiDataWidth          (WideDataWidth),
    .AxiUserWidth          (UserWidth),

    .slv_req_t (wide_out_req_t),
    .slv_resp_t(wide_out_resp_t),
    .mst_req_t (axi_wide_clu_wide_to_narrow_req_t),
    .mst_resp_t(axi_wide_clu_wide_to_narrow_resp_t)
  ) wide_to_narrow_mst_iw_converter (
    .clk_i     (soc_clk_i),
    .rst_ni    (rst_ni),
    .slv_req_i (axi_from_cluster_wide_to_narrow_req),
    .slv_resp_o(axi_from_cluster_wide_to_narrow_resp),
    .mst_req_o (axi_from_cluster_wide_to_narrow_iwc_req),
    .mst_resp_i(axi_from_cluster_wide_to_narrow_iwc_resp)
  );

  // SoC side Wide-to-narrow data width converter for bypasses

  axi_dw_converter #(
    .AxiMaxReads(2),

    .AxiSlvPortDataWidth(WideDataWidth),
    .AxiMstPortDataWidth(NarrowDataWidth),
    .AxiAddrWidth       (AddrWidth),
    .AxiIdWidth         (SocNarrowMasterIdWidth),

    .aw_chan_t(axi_narrow_soc_out_aw_chan_t),
    .b_chan_t (axi_narrow_soc_out_b_chan_t),
    .ar_chan_t(axi_narrow_soc_out_ar_chan_t),

    .slv_r_chan_t(axi_wide_clu_wide_to_narrow_r_chan_t),
    .slv_w_chan_t(axi_wide_clu_wide_to_narrow_w_chan_t),
    .mst_r_chan_t(axi_narrow_soc_out_r_chan_t),
    .mst_w_chan_t(axi_narrow_soc_out_w_chan_t),

    .axi_mst_req_t (narrow_out_req_t),
    .axi_mst_resp_t(narrow_out_resp_t),
    .axi_slv_req_t (axi_wide_clu_wide_to_narrow_req_t),
    .axi_slv_resp_t(axi_wide_clu_wide_to_narrow_resp_t)
  ) i_wide_to_narrow_dw_converter (
    .clk_i     (soc_clk_i),
    .rst_ni,
    .slv_req_i (axi_from_cluster_wide_to_narrow_iwc_req),
    .slv_resp_o(axi_from_cluster_wide_to_narrow_iwc_resp),
    .mst_req_o (narrow_out_req_o[1]),
    .mst_resp_i(narrow_out_resp_i[1])
  );

  // Cluster-side reduce ID Width from SoC AXI Slave ID Width to 1
  // This relaxes pressure from Snitch Cluster Interco

  axi_iw_converter #(
    .AxiSlvPortIdWidth     (SocNarrowSlaveIdWidth),
    .AxiMstPortIdWidth     (ClusterNarrowSlaveIdWidth),
    .AxiSlvPortMaxUniqIds  (32),
    .AxiSlvPortMaxTxnsPerId(1),
    .AxiSlvPortMaxTxns     (2),
    .AxiMstPortMaxUniqIds  (2),
    .AxiMstPortMaxTxnsPerId(2),
    .AxiAddrWidth          (AddrWidth),
    .AxiDataWidth          (WideDataWidth),
    .AxiUserWidth          (UserWidth),

    .slv_req_t (narrow_in_req_t),
    .slv_resp_t(narrow_in_resp_t),
    .mst_req_t (clu_narrow_in_req_t),
    .mst_resp_t(clu_narrow_in_resp_t)
  ) i_narrow_slv_to_narrow_mst_iw_converter (
    .clk_i     (clu_clk_i),
    .rst_ni    (rst_ni),
    .slv_req_i (axi_to_cluster_narrow_req),
    .slv_resp_o(axi_to_cluster_narrow_resp),
    .mst_req_o (clu_narrow_in_req_o),
    .mst_resp_i(clu_narrow_in_resp_i)
  );

  // NARROW MASTER PORT Cluster-side ID WIDTH CONVERSION

  axi_iw_converter #(
    .AxiSlvPortIdWidth(ClusterNarrowMasterIdWidth),
    .AxiMstPortIdWidth(SocNarrowMasterIdWidth),

    .AxiSlvPortMaxUniqIds  (2),
    .AxiSlvPortMaxTxnsPerId(2),
    .AxiSlvPortMaxTxns     (4),

    .AxiMstPortMaxUniqIds  (2),
    .AxiMstPortMaxTxnsPerId(4),

    .AxiAddrWidth(AddrWidth),
    .AxiDataWidth(NarrowDataWidth),
    .AxiUserWidth(UserWidth),
    .slv_req_t   (clu_narrow_out_req_t),
    .slv_resp_t  (clu_narrow_out_resp_t),
    .mst_req_t   (narrow_out_req_t),
    .mst_resp_t  (narrow_out_resp_t)
  ) narrow_mst_iw_converter (
    .clk_i     (clu_clk_i),
    .rst_ni    (rst_ni),
    .slv_req_i (axi_from_cluster_narrow_iwc_req),
    .slv_resp_o(axi_from_cluster_narrow_iwc_resp),
    .mst_req_o (axi_from_cluster_narrow_req),
    .mst_resp_i(axi_from_cluster_narrow_resp)
  );

  // WIDE MASTER PORT Cluster-side ID WIDTH CONVERSION

  axi_iw_converter #(
    .AxiSlvPortIdWidth(SocWideMasterIdWidth),
    .AxiMstPortIdWidth(SocWideMasterIdWidth),

    .AxiSlvPortMaxUniqIds  (2),
    .AxiSlvPortMaxTxnsPerId(2),
    .AxiSlvPortMaxTxns     (4),

    .AxiMstPortMaxUniqIds  (2),
    .AxiMstPortMaxTxnsPerId(4),

    .AxiAddrWidth(AddrWidth),
    .AxiDataWidth(WideDataWidth),
    .AxiUserWidth(UserWidth),
    .slv_req_t   (clu_wide_out_req_t),
    .slv_resp_t  (clu_wide_out_resp_t),
    .mst_req_t   (wide_out_req_t),
    .mst_resp_t  (wide_out_resp_t)
  ) wide_mst_iw_converter (
    .clk_i     (clu_clk_i),
    .rst_ni    (rst_ni),
    .slv_req_i (axi_from_cluster_wide_iwc_req),
    .slv_resp_o(axi_from_cluster_wide_iwc_resp),
    .mst_req_o (axi_from_cluster_wide_req),
    .mst_resp_i(axi_from_cluster_wide_resp)
  );

  // AXI Narrow CDC from SoC to Cluster

  axi_cdc #(
    .aw_chan_t (axi_narrow_soc_in_aw_chan_t),
    .w_chan_t  (axi_narrow_soc_in_w_chan_t),
    .b_chan_t  (axi_narrow_soc_in_b_chan_t),
    .ar_chan_t (axi_narrow_soc_in_ar_chan_t),
    .r_chan_t  (axi_narrow_soc_in_r_chan_t),
    .axi_req_t (narrow_in_req_t),
    .axi_resp_t(narrow_in_resp_t)
  ) narrow_slv_cdc (
    .src_clk_i (soc_clk_i),
    .src_rst_ni(rst_ni),
    .src_req_i (narrow_in_req_i),
    .src_resp_o(narrow_in_resp_o),

    .dst_clk_i (clu_clk_i),
    .dst_rst_ni(rst_ni),
    .dst_req_o (axi_to_cluster_narrow_req),
    .dst_resp_i(axi_to_cluster_narrow_resp)
  );

  // AXI Narrow CDC from Cluster to SoC

  axi_cdc #(
    .aw_chan_t (axi_narrow_soc_out_aw_chan_t),
    .w_chan_t  (axi_narrow_soc_out_w_chan_t),
    .b_chan_t  (axi_narrow_soc_out_b_chan_t),
    .ar_chan_t (axi_narrow_soc_out_ar_chan_t),
    .r_chan_t  (axi_narrow_soc_out_r_chan_t),
    .axi_req_t (narrow_out_req_t),
    .axi_resp_t(narrow_out_resp_t)
  ) narrow_mst_cdc (
    .src_clk_i (clu_clk_i),
    .src_rst_ni(rst_ni),
    .src_req_i (axi_from_cluster_narrow_req),
    .src_resp_o(axi_from_cluster_narrow_resp),

    .dst_clk_i (soc_clk_i),
    .dst_rst_ni(rst_ni),
    .dst_req_o (narrow_out_req_o[0]),
    .dst_resp_i(narrow_out_resp_i[0])
  );

  // AXI Wide CDC from Cluster to SoC

  axi_cdc #(
    .aw_chan_t (axi_wide_clu_out_aw_chan_t),
    .w_chan_t  (axi_wide_clu_out_w_chan_t),
    .b_chan_t  (axi_wide_clu_out_b_chan_t),
    .ar_chan_t (axi_wide_clu_out_ar_chan_t),
    .r_chan_t  (axi_wide_clu_out_r_chan_t),
    .axi_req_t (wide_out_req_t),
    .axi_resp_t(wide_out_resp_t)
  ) wide_mst_cdc (
    .src_clk_i (clu_clk_i),
    .src_rst_ni(rst_ni),
    .src_req_i (axi_from_cluster_wide_req),
    .src_resp_o(axi_from_cluster_wide_resp),

    .dst_clk_i (soc_clk_i),
    .dst_rst_ni(rst_ni),
    .dst_req_o (axi_from_cluster_wide_premux_req),
    .dst_resp_i(axi_from_cluster_wide_premux_resp)
  );

  // Validate parameters
`ifndef VERILATOR
`ifndef XSIM

  write_wide_bypass :
  assert property (
     @(posedge clu_clk_i) ((axi_from_cluster_wide_premux_req.aw_valid & wide_mem_bypass_mode_i) |->
          (axi_from_cluster_wide_to_narrow_req.aw_valid &
           ~axi_from_cluster_wide_memisl_req.aw_valid)))
  else $fatal(1, "Bypass Mode ON, but write request routed toward the Wide interconnect");

  read_wide_bypass :
  assert property (
     @(posedge clu_clk_i) ((axi_from_cluster_wide_premux_req.ar_valid & wide_mem_bypass_mode_i) |->
        (axi_from_cluster_wide_to_narrow_req.ar_valid &
         ~axi_from_cluster_wide_memisl_req.ar_valid)))
  else $fatal(1, "Bypass Mode ON, but read request routed toward the Wide interocnnect");


`endif
`endif


endmodule : chimera_cluster_adapter
