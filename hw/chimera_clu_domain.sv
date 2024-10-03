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

// Wraps all snitch-type clusters in chimera
module chimera_clu_domain
  import chimera_pkg::*;
  import cheshire_pkg::*;
#(
  parameter chimera_cfg_t Cfg               = '0,
  parameter type          narrow_in_req_t   = logic,
  parameter type          narrow_in_resp_t  = logic,
  parameter type          narrow_out_req_t  = logic,
  parameter type          narrow_out_resp_t = logic,
  parameter type          wide_out_req_t    = logic,
  parameter type          wide_out_resp_t   = logic
) (
  input  logic                                                              soc_clk_i,
  input  logic             [                               ExtClusters-1:0] clu_clk_i,
  input  logic             [                               ExtClusters-1:0] rst_sync_ni,
  input  logic             [                               ExtClusters-1:0] widemem_bypass_i,
  //-----------------------------
  // Interrupt ports
  //-----------------------------
  input  logic             [iomsb(NumIrqCtxts*Cfg.ChsCfg.NumExtIrqHarts):0] xeip_i,
  input  logic             [            iomsb(Cfg.ChsCfg.NumExtIrqHarts):0] mtip_i,
  input  logic             [            iomsb(Cfg.ChsCfg.NumExtIrqHarts):0] msip_i,
  input  logic             [            iomsb(Cfg.ChsCfg.NumExtDbgHarts):0] debug_req_i,
  //-----------------------------
  // Narrow AXI ports
  //-----------------------------
  input  narrow_in_req_t   [                               ExtClusters-1:0] narrow_in_req_i,
  output narrow_in_resp_t  [                               ExtClusters-1:0] narrow_in_resp_o,
  output narrow_out_req_t  [              iomsb(Cfg.ChsCfg.AxiExtNumMst):0] narrow_out_req_o,
  input  narrow_out_resp_t [              iomsb(Cfg.ChsCfg.AxiExtNumMst):0] narrow_out_resp_i,
  //-----------------------------
  // Wide AXI ports
  //-----------------------------
  output wide_out_req_t    [          iomsb(Cfg.ChsCfg.AxiExtNumWideMst):0] wide_out_req_o,
  input  wide_out_resp_t   [          iomsb(Cfg.ChsCfg.AxiExtNumWideMst):0] wide_out_resp_i,
  //-----------------------------
  // Isolation control ports
  //-----------------------------
  input  logic             [                               ExtClusters-1:0] isolate_i,
  output logic             [                               ExtClusters-1:0] isolate_o
);

  // Axi parameters
  localparam int unsigned AxiWideDataWidth = Cfg.ChsCfg.AxiDataWidth * Cfg.MemIslNarrowToWideFactor;
  localparam int unsigned AxiWideSlvIdWidth = Cfg.MemIslAxiMstIdWidth + $clog2(Cfg.MemIslWidePorts);
  localparam int unsigned AxiSlvIdWidth = Cfg.ChsCfg.AxiMstIdWidth + $clog2(
      cheshire_pkg::gen_axi_in(Cfg).num_in
  );

  // Isolated AXI signals
  narrow_in_req_t   [    iomsb(Cfg.ChsCfg.AxiExtNumSlv):0] narrow_in_isolated_req;
  narrow_in_resp_t  [    iomsb(Cfg.ChsCfg.AxiExtNumSlv):0] narrow_in_isolated_resp;
  narrow_out_req_t  [    iomsb(Cfg.ChsCfg.AxiExtNumMst):0] narrow_out_isolated_req;
  narrow_out_resp_t [    iomsb(Cfg.ChsCfg.AxiExtNumMst):0] narrow_out_isolated_resp;
  wide_out_req_t    [iomsb(Cfg.ChsCfg.AxiExtNumWideMst):0] wide_out_isolated_req;
  wide_out_resp_t   [iomsb(Cfg.ChsCfg.AxiExtNumWideMst):0] wide_out_isolated_resp;

  logic             [    iomsb(Cfg.ChsCfg.AxiExtNumSlv):0] isolated_narrow_in;
  logic             [    iomsb(Cfg.ChsCfg.AxiExtNumMst):0] isolated_narrow_out;
  logic             [iomsb(Cfg.ChsCfg.AxiExtNumWideMst):0] isolated_wide_out;



  for (genvar extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++) begin : gen_clusters

    if (Cfg.IsolateClusters == 1) begin : gen_cluster_iso
      // Add AXI isolation at the Narrow Input Interface
      axi_isolate #(
        .NumPending          (Cfg.ChsCfg.AxiMaxSlvTrans),
        .TerminateTransaction(0),
        .AtopSupport         (1),
        .AxiAddrWidth        (Cfg.ChsCfg.AddrWidth),
        .AxiDataWidth        (Cfg.ChsCfg.AxiDataWidth),
        .AxiIdWidth          (AxiSlvIdWidth),
        .AxiUserWidth        (Cfg.ChsCfg.AxiUserWidth),
        .axi_req_t           (narrow_in_req_t),
        .axi_resp_t          (narrow_in_resp_t)
      ) i_iso_narrow_in_cluster (
        .clk_i     (soc_clk_i),
        .rst_ni    (rst_sync_ni[extClusterIdx]),
        .slv_req_i (narrow_in_req_i[extClusterIdx]),
        .slv_resp_o(narrow_in_resp_o[extClusterIdx]),
        .mst_req_o (narrow_in_isolated_req[extClusterIdx]),
        .mst_resp_i(narrow_in_isolated_resp[extClusterIdx]),
        .isolate_i (isolate_i[extClusterIdx]),
        .isolated_o(isolated_narrow_in[extClusterIdx])
      );

      // Add AXI isolation at the Narrow Output Interface.
      // Two ports for each cluster: one to convert stray wides, one for the original narrow
      for (
          genvar narrowOutIdx = 2 * extClusterIdx;
          narrowOutIdx < 2 * extClusterIdx + 2;
          narrowOutIdx++
      ) begin : gen_iso_narrow_out
        axi_isolate #(
          .NumPending          (Cfg.ChsCfg.AxiMaxSlvTrans),
          .TerminateTransaction(0),
          .AtopSupport         (1),
          .AxiAddrWidth        (Cfg.ChsCfg.AddrWidth),
          .AxiDataWidth        (Cfg.ChsCfg.AxiDataWidth),
          .AxiIdWidth          (Cfg.ChsCfg.AxiMstIdWidth),
          .AxiUserWidth        (Cfg.ChsCfg.AxiUserWidth),
          .axi_req_t           (narrow_out_req_t),
          .axi_resp_t          (narrow_out_resp_t)
        ) i_iso_narrow_out_cluster (
          .clk_i     (soc_clk_i),
          .rst_ni    (rst_sync_ni[extClusterIdx]),
          .slv_req_i (narrow_out_isolated_req[narrowOutIdx]),
          .slv_resp_o(narrow_out_isolated_resp[narrowOutIdx]),
          .mst_req_o (narrow_out_req_o[narrowOutIdx]),
          .mst_resp_i(narrow_out_resp_i[narrowOutIdx]),
          .isolate_i (isolate_i[extClusterIdx]),
          .isolated_o(isolated_narrow_out[narrowOutIdx])
        );
      end : gen_iso_narrow_out

      // Add AXI isolation at the Wide Interface
      axi_isolate #(
        .NumPending          (Cfg.ChsCfg.AxiMaxSlvTrans),
        .TerminateTransaction(0),
        .AtopSupport         (1),
        .AxiAddrWidth        (Cfg.ChsCfg.AddrWidth),
        .AxiDataWidth        (AxiWideDataWidth),
        .AxiIdWidth          (Cfg.MemIslAxiMstIdWidth),    // To Check
        .AxiUserWidth        (Cfg.ChsCfg.AxiUserWidth),
        .axi_req_t           (wide_out_req_t),
        .axi_resp_t          (wide_out_resp_t)
      ) i_iso_wide_cluster (
        .clk_i     (soc_clk_i),
        .rst_ni    (rst_sync_ni[extClusterIdx]),
        .slv_req_i (wide_out_isolated_req[extClusterIdx]),
        .slv_resp_o(wide_out_isolated_resp[extClusterIdx]),
        .mst_req_o (wide_out_req_o[extClusterIdx]),
        .mst_resp_i(wide_out_resp_i[extClusterIdx]),
        .isolate_i (isolate_i[extClusterIdx]),
        .isolated_o(isolated_wide_out[extClusterIdx])
      );

      assign isolate_o[extClusterIdx] = isolated_narrow_in[extClusterIdx] &
                                      isolated_narrow_out[2*extClusterIdx+:2] &
                                      isolated_wide_out[extClusterIdx];

    end else begin : gen_no_cluster_iso  // bypass isolate if not required

      assign narrow_in_isolated_req[extClusterIdx] = narrow_in_req_i[extClusterIdx];
      assign narrow_in_resp_o[extClusterIdx] = narrow_in_isolated_resp[extClusterIdx];

      assign narrow_out_req_o[2*extClusterIdx] = narrow_out_isolated_req[2*extClusterIdx];
      assign narrow_out_isolated_resp[2*extClusterIdx] = narrow_out_resp_i[2*extClusterIdx];

      assign narrow_out_req_o[2*extClusterIdx+1] = narrow_out_isolated_req[2*extClusterIdx+1];
      assign narrow_out_isolated_resp[2*extClusterIdx+1] = narrow_out_resp_i[2*extClusterIdx+1];

      assign wide_out_req_o[extClusterIdx] = wide_out_isolated_req[extClusterIdx];
      assign wide_out_isolated_resp[extClusterIdx] = wide_out_resp_i[extClusterIdx];

      assign isolate_o[extClusterIdx] = '0;

    end : gen_no_cluster_iso

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
      .rst_ni             (rst_sync_ni[extClusterIdx]),
      .widemem_bypass_i   (widemem_bypass_i[extClusterIdx]),
      .debug_req_i        (debug_req_i[`PREVNRCORES(extClusterIdx)+:`NRCORES(extClusterIdx)]),
      .meip_i             (xeip_i[`PREVNRCORES(extClusterIdx)+:`NRCORES(extClusterIdx)]),
      .mtip_i             (mtip_i[`PREVNRCORES(extClusterIdx)+:`NRCORES(extClusterIdx)]),
      .msip_i             (msip_i[`PREVNRCORES(extClusterIdx)+:`NRCORES(extClusterIdx)]),
      .hart_base_id_i     (10'(`PREVNRCORES(extClusterIdx) + 1)),
      .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[extClusterIdx][Cfg.ChsCfg.AddrWidth-1:0]),
      .boot_addr_i        (SnitchBootROMRegionStart[31:0]),

      .narrow_in_req_i  (narrow_in_isolated_req[extClusterIdx]),
      .narrow_in_resp_o (narrow_in_isolated_resp[extClusterIdx]),
      .narrow_out_req_o (narrow_out_isolated_req[2*extClusterIdx+:2]),
      .narrow_out_resp_i(narrow_out_isolated_resp[2*extClusterIdx+:2]),

      .wide_out_req_o (wide_out_isolated_req[extClusterIdx]),
      .wide_out_resp_i(wide_out_isolated_resp[extClusterIdx])
    );

  end : gen_clusters


endmodule
