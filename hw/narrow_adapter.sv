// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

module narrow_adapter #(
  parameter type narrow_in_req_t       = logic,
  parameter type narrow_in_resp_t      = logic,
  parameter type narrow_out_req_t      = logic,
  parameter type narrow_out_resp_t     = logic,
  parameter type clu_narrow_in_req_t   = logic,
  parameter type clu_narrow_in_resp_t  = logic,
  parameter type clu_narrow_out_req_t  = logic,
  parameter type clu_narrow_out_resp_t = logic,
  parameter int  MstPorts              = 2,
  parameter int  SlvPorts              = 1
) (
  input logic soc_clk_i,
  input logic rst_ni,

  // From SoC
  input  narrow_in_req_t   [SlvPorts-1:0] narrow_in_req_i,
  output narrow_in_resp_t  [SlvPorts-1:0] narrow_in_resp_o,
  output narrow_out_req_t  [MstPorts-1:0] narrow_out_req_o,
  input  narrow_out_resp_t [MstPorts-1:0] narrow_out_resp_i,

  // To Clu
  output clu_narrow_in_req_t   [SlvPorts-1:0] clu_narrow_in_req_o,
  input  clu_narrow_in_resp_t  [SlvPorts-1:0] clu_narrow_in_resp_i,
  input  clu_narrow_out_req_t  [MstPorts-1:0] clu_narrow_out_req_i,
  output clu_narrow_out_resp_t [MstPorts-1:0] clu_narrow_out_resp_o

);

  `include "axi/typedef.svh"

  localparam int SoCNarrowDataWidth = $bits(narrow_out_req_o[0].w.data);
  localparam int CluNarrowDataWidth = $bits(clu_narrow_in_req_o[0].w.data);
  localparam int AddrWidth = $bits(narrow_out_req_o[0].aw.addr);
  localparam int UserWidth = $bits(narrow_out_req_o[0].aw.user);

  localparam int SocNarrowMasterIdWidth = $bits(narrow_out_req_o[0].aw.id);
  localparam int SocNarrowSlaveIdWidth = $bits(narrow_in_req_i[0].aw.id);

  typedef logic [UserWidth-1:0] axi_user_width_t;
  typedef logic [AddrWidth-1:0] axi_addr_width_t;

  typedef logic [SoCNarrowDataWidth-1:0] axi_soc_narrow_data_width_t;
  typedef logic [SoCNarrowDataWidth/8-1:0] axi_soc_narrow_strb_width_t;

  typedef logic [CluNarrowDataWidth-1:0] axi_clu_narrow_data_width_t;
  typedef logic [CluNarrowDataWidth/8-1:0] axi_clu_narrow_strb_width_t;

  typedef logic [SocNarrowMasterIdWidth-1:0] axi_narrow_mst_id_width_t;
  typedef logic [SocNarrowSlaveIdWidth-1:0] axi_narrow_slv_id_width_t;

  `AXI_TYPEDEF_ALL(axi_narrow_out_soc, axi_addr_width_t, axi_narrow_mst_id_width_t,
                   axi_soc_narrow_data_width_t, axi_soc_narrow_strb_width_t, axi_user_width_t)

  `AXI_TYPEDEF_ALL(axi_narrow_out_clu, axi_addr_width_t, axi_narrow_mst_id_width_t,
                   axi_clu_narrow_data_width_t, axi_clu_narrow_strb_width_t, axi_user_width_t)

  `AXI_TYPEDEF_ALL(axi_narrow_in_soc, axi_addr_width_t, axi_narrow_slv_id_width_t,
                   axi_soc_narrow_data_width_t, axi_soc_narrow_strb_width_t, axi_user_width_t)

  `AXI_TYPEDEF_ALL(axi_narrow_in_clu, axi_addr_width_t, axi_narrow_slv_id_width_t,
                   axi_clu_narrow_data_width_t, axi_clu_narrow_strb_width_t, axi_user_width_t)


  genvar i;
  generate
    for (i = 0; i < MstPorts; i++) begin : gen_clu_to_soc_conv
      axi_dw_converter #(
        .AxiMaxReads(2),

        .AxiSlvPortDataWidth(CluNarrowDataWidth),
        .AxiMstPortDataWidth(SoCNarrowDataWidth),
        .AxiAddrWidth       (AddrWidth),
        .AxiIdWidth         (SocNarrowMasterIdWidth),

        .aw_chan_t(axi_narrow_out_soc_aw_chan_t),
        .b_chan_t (axi_narrow_out_soc_b_chan_t),
        .ar_chan_t(axi_narrow_out_soc_ar_chan_t),

        .slv_r_chan_t(axi_narrow_out_clu_r_chan_t),
        .slv_w_chan_t(axi_narrow_out_clu_aw_chan_t),
        .mst_r_chan_t(axi_narrow_out_soc_r_chan_t),
        .mst_w_chan_t(axi_narrow_out_soc_w_chan_t),

        .axi_mst_req_t (axi_narrow_out_soc_req_t),
        .axi_mst_resp_t(axi_narrow_out_soc_resp_t),
        .axi_slv_req_t (clu_narrow_out_req_t),
        .axi_slv_resp_t(clu_narrow_out_resp_t)
      ) i_clu_to_soc_dw_converter (
        .clk_i     (soc_clk_i),
        .rst_ni,
        .slv_req_i (clu_narrow_out_req_i[i]),
        .slv_resp_o(clu_narrow_out_resp_o[i]),
        .mst_req_o (narrow_out_req_o[i]),
        .mst_resp_i(narrow_out_resp_i[i])
      );
    end

  endgenerate
  generate

    for (i = 0; i < SlvPorts; i++) begin : gen_soc_to_clu_conv
      axi_dw_converter #(
        .AxiMaxReads(2),

        .AxiSlvPortDataWidth(SoCNarrowDataWidth),
        .AxiMstPortDataWidth(CluNarrowDataWidth),
        .AxiAddrWidth       (AddrWidth),
        .AxiIdWidth         (SocNarrowSlaveIdWidth),

        .aw_chan_t(axi_narrow_in_clu_aw_chan_t),
        .b_chan_t (axi_narrow_in_clu_b_chan_t),
        .ar_chan_t(axi_narrow_in_clu_ar_chan_t),

        .slv_r_chan_t(axi_narrow_in_soc_r_chan_t),
        .slv_w_chan_t(axi_narrow_in_soc_w_chan_t),
        .mst_r_chan_t(axi_narrow_in_clu_r_chan_t),
        .mst_w_chan_t(axi_narrow_in_clu_w_chan_t),

        .axi_mst_req_t (axi_narrow_in_clu_req_t),
        .axi_mst_resp_t(axi_narrow_in_clu_resp_t),
        .axi_slv_req_t (axi_narrow_in_soc_req_t),
        .axi_slv_resp_t(axi_narrow_in_soc_resp_t)
      ) i_soc_to_clu_dw_converter (
        .clk_i     (soc_clk_i),
        .rst_ni,
        .slv_req_i (narrow_in_req_i[i]),
        .slv_resp_o(narrow_in_resp_o[i]),
        .mst_req_o (clu_narrow_in_req_o[i]),
        .mst_resp_i(clu_narrow_in_resp_i[i])
      );
    end  // for (i = 0; i < SlvPorts; i++)
  endgenerate

endmodule
