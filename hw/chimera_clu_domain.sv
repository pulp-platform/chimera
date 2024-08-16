// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

`define NRCORES(extClusterIdx) ChimeraClusterCfg.NrCores[extClusterIdx]
`define PREVNRCORES(extClusterIdx) \
 _sumVector( \
        ChimeraClusterCfg.NrCores, extClusterIdx \
    )

module chimera_clu_domain
  import chimera_pkg::*;
  import cheshire_pkg::*;
#(
  parameter cheshire_cfg_t Cfg               = '0,
  parameter type           narrow_in_req_t   = logic,
  parameter type           narrow_in_resp_t  = logic,
  parameter type           narrow_out_req_t  = logic,
  parameter type           narrow_out_resp_t = logic,
  parameter type           wide_out_req_t    = logic,
  parameter type           wide_out_resp_t   = logic
) (
  input  logic                                                       soc_clk_i,
  input  logic             [                        ExtClusters-1:0] clu_clk_i,
  input  logic                                                       rst_ni,
  input  logic             [                        ExtClusters-1:0] widemem_bypass_i,
  //-----------------------------
  // Interrupt ports
  //-----------------------------
  input  logic             [iomsb(NumIrqCtxts*Cfg.NumExtIrqHarts):0] xeip_i,
  input  logic             [            iomsb(Cfg.NumExtIrqHarts):0] mtip_i,
  input  logic             [            iomsb(Cfg.NumExtIrqHarts):0] msip_i,
  input  logic             [            iomsb(Cfg.NumExtDbgHarts):0] debug_req_i,
  //-----------------------------
  // Narrow AXI ports
  //-----------------------------
  input  narrow_in_req_t   [              iomsb(Cfg.AxiExtNumSlv):0] narrow_in_req_i,
  output narrow_in_resp_t  [              iomsb(Cfg.AxiExtNumSlv):0] narrow_in_resp_o,
  output narrow_out_req_t  [              iomsb(Cfg.AxiExtNumMst):0] narrow_out_req_o,
  input  narrow_out_resp_t [              iomsb(Cfg.AxiExtNumMst):0] narrow_out_resp_i,
  //-----------------------------
  // Wide AXI ports
  //-----------------------------
  output wide_out_req_t    [          iomsb(Cfg.AxiExtNumWideMst):0] wide_out_req_o,
  input  wide_out_resp_t   [          iomsb(Cfg.AxiExtNumWideMst):0] wide_out_resp_i
);

  for (genvar extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++) begin : gen_clusters

    chimera_cluster #(
      .Cfg              (Cfg),
      .NrCores          (`NRCORES(extClusterIdx)),
      .narrow_in_req_t  (narrow_in_req_t),
      .narrow_in_resp_t (narrow_in_resp_t),
      .narrow_out_req_t (narrow_out_req_t),
      .narrow_out_resp_t(narrow_out_resp_t),
      .wide_out_req_t   (wide_out_req_t),
      .wide_out_resp_t  (wide_out_resp_t)
    ) i_chimera_cluster (
      .soc_clk_i          (soc_clk_i),
      .clu_clk_i          (clu_clk_i[extClusterIdx]),
      .rst_ni,
      .widemem_bypass_i   (widemem_bypass_i[extClusterIdx]),
      .debug_req_i        (debug_req_i[`PREVNRCORES(extClusterIdx)+:`NRCORES(extClusterIdx)]),
      .meip_i             (xeip_i[`PREVNRCORES(extClusterIdx)+:`NRCORES(extClusterIdx)]),
      .mtip_i             (mtip_i[`PREVNRCORES(extClusterIdx)+:`NRCORES(extClusterIdx)]),
      .msip_i             (msip_i[`PREVNRCORES(extClusterIdx)+:`NRCORES(extClusterIdx)]),
      .hart_base_id_i     (10'(`PREVNRCORES(extClusterIdx) + 1)),
      .cluster_base_addr_i(Cfg.AxiExtRegionStart[extClusterIdx][Cfg.AddrWidth-1:0]),
      .boot_addr_i        (SnitchBootROMRegionStart[31:0]),

      .narrow_in_req_i  (narrow_in_req_i[extClusterIdx]),
      .narrow_in_resp_o (narrow_in_resp_o[extClusterIdx]),
      .narrow_out_req_o (narrow_out_req_o[2*extClusterIdx+:2]),
      .narrow_out_resp_i(narrow_out_resp_i[2*extClusterIdx+:2]),
      .wide_out_req_o   (wide_out_req_o[extClusterIdx]),
      .wide_out_resp_i  (wide_out_resp_i[extClusterIdx])
    );

  end : gen_clusters


endmodule
