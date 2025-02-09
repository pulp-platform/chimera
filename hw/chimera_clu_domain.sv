// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

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
  input  logic             [                               ExtClusters-1:0] rst_ni,
  input  logic             [                               ExtClusters-1:0] widemem_bypass_i,
  input  logic             [                                          31:0] boot_addr_i,
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

`ifdef TARGET_TUEDCIM

  chimera_cluster_tuedcim #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(TUEDCIMIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_tuedcim (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[TUEDCIMIDX]),
    .rst_ni             (rst_ni[TUEDCIMIDX]),
    .widemem_bypass_i   (widemem_bypass_i[TUEDCIMIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(TUEDCIMIDX)+:`NRCORES(TUEDCIMIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(TUEDCIMIDX)+:`NRCORES(TUEDCIMIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(TUEDCIMIDX)+:`NRCORES(TUEDCIMIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(TUEDCIMIDX)+:`NRCORES(TUEDCIMIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(TUEDCIMIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[TUEDCIMIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[TUEDCIMIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[TUEDCIMIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*TUEDCIMIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*TUEDCIMIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[TUEDCIMIDX]),
    .wide_out_resp_i  (wide_out_resp_i[TUEDCIMIDX])
  );

`else

  chimera_cluster #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(TUEDCIMIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_0 (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[TUEDCIMIDX]),
    .rst_ni             (rst_ni[TUEDCIMIDX]),
    .widemem_bypass_i   (widemem_bypass_i[TUEDCIMIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(TUEDCIMIDX)+:`NRCORES(TUEDCIMIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(TUEDCIMIDX)+:`NRCORES(TUEDCIMIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(TUEDCIMIDX)+:`NRCORES(TUEDCIMIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(TUEDCIMIDX)+:`NRCORES(TUEDCIMIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(TUEDCIMIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[TUEDCIMIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[TUEDCIMIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[TUEDCIMIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*TUEDCIMIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*TUEDCIMIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[TUEDCIMIDX]),
    .wide_out_resp_i  (wide_out_resp_i[TUEDCIMIDX])
  );

`endif
`ifdef TARGET_TUEMEGA

  chimera_cluster_tuemega #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(TUEMEGAIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_tuemega (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[TUEMEGAIDX]),
    .rst_ni             (rst_ni[TUEMEGAIDX]),
    .widemem_bypass_i   (widemem_bypass_i[TUEMEGAIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(TUEMEGAIDX)+:`NRCORES(TUEMEGAIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(TUEMEGAIDX)+:`NRCORES(TUEMEGAIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(TUEMEGAIDX)+:`NRCORES(TUEMEGAIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(TUEMEGAIDX)+:`NRCORES(TUEMEGAIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(TUEMEGAIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[TUEMEGAIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[TUEMEGAIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[TUEMEGAIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*TUEMEGAIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*TUEMEGAIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[TUEMEGAIDX]),
    .wide_out_resp_i  (wide_out_resp_i[TUEMEGAIDX])
  );

`else

  chimera_cluster #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(TUEMEGAIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_1 (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[TUEMEGAIDX]),
    .rst_ni             (rst_ni[TUEMEGAIDX]),
    .widemem_bypass_i   (widemem_bypass_i[TUEMEGAIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(TUEMEGAIDX)+:`NRCORES(TUEMEGAIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(TUEMEGAIDX)+:`NRCORES(TUEMEGAIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(TUEMEGAIDX)+:`NRCORES(TUEMEGAIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(TUEMEGAIDX)+:`NRCORES(TUEMEGAIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(TUEMEGAIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[TUEMEGAIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[TUEMEGAIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[TUEMEGAIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*TUEMEGAIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*TUEMEGAIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[TUEMEGAIDX]),
    .wide_out_resp_i  (wide_out_resp_i[TUEMEGAIDX])
  );


`endif

`ifdef TARGET_TUDDCIM

  chimera_cluster_tuddcim #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(TUDDCIMIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_tuddcim (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[TUDDCIMIDX]),
    .rst_ni             (rst_ni[TUDDCIMIDX]),
    .widemem_bypass_i   (widemem_bypass_i[TUDDCIMIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(TUDDCIMIDX)+:`NRCORES(TUDDCIMIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(TUDDCIMIDX)+:`NRCORES(TUDDCIMIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(TUDDCIMIDX)+:`NRCORES(TUDDCIMIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(TUDDCIMIDX)+:`NRCORES(TUDDCIMIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(TUDDCIMIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[TUDDCIMIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[TUDDCIMIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[TUDDCIMIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*TUDDCIMIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*TUDDCIMIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[TUDDCIMIDX]),
    .wide_out_resp_i  (wide_out_resp_i[TUDDCIMIDX])
  );

`else

  chimera_cluster #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(TUDDCIMIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_2 (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[TUDDCIMIDX]),
    .rst_ni             (rst_ni[TUDDCIMIDX]),
    .widemem_bypass_i   (widemem_bypass_i[TUDDCIMIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(TUDDCIMIDX)+:`NRCORES(TUDDCIMIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(TUDDCIMIDX)+:`NRCORES(TUDDCIMIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(TUDDCIMIDX)+:`NRCORES(TUDDCIMIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(TUDDCIMIDX)+:`NRCORES(TUDDCIMIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(TUDDCIMIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[TUDDCIMIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[TUDDCIMIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[TUDDCIMIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*TUDDCIMIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*TUDDCIMIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[TUDDCIMIDX]),
    .wide_out_resp_i  (wide_out_resp_i[TUDDCIMIDX])
  );


`endif

`ifdef TARGET_KULCLUSTER

  chimera_cluster_kulcluster #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(KULCLUSTERIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_kulcluster (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[KULCLUSTERIDX]),
    .rst_ni             (rst_ni[KULCLUSTERIDX]),
    .widemem_bypass_i   (widemem_bypass_i[KULCLUSTERIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(KULCLUSTERIDX)+:`NRCORES(KULCLUSTERIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(KULCLUSTERIDX)+:`NRCORES(KULCLUSTERIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(KULCLUSTERIDX)+:`NRCORES(KULCLUSTERIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(KULCLUSTERIDX)+:`NRCORES(KULCLUSTERIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(KULCLUSTERIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[KULCLUSTERIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[KULCLUSTERIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[KULCLUSTERIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*KULCLUSTERIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*KULCLUSTERIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[KULCLUSTERIDX]),
    .wide_out_resp_i  (wide_out_resp_i[KULCLUSTERIDX])
  );

`else

  chimera_cluster #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(KULCLUSTERIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_3 (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[KULCLUSTERIDX]),
    .rst_ni             (rst_ni[KULCLUSTERIDX]),
    .widemem_bypass_i   (widemem_bypass_i[KULCLUSTERIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(KULCLUSTERIDX)+:`NRCORES(KULCLUSTERIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(KULCLUSTERIDX)+:`NRCORES(KULCLUSTERIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(KULCLUSTERIDX)+:`NRCORES(KULCLUSTERIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(KULCLUSTERIDX)+:`NRCORES(KULCLUSTERIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(KULCLUSTERIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[KULCLUSTERIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[KULCLUSTERIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[KULCLUSTERIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*KULCLUSTERIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*KULCLUSTERIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[KULCLUSTERIDX]),
    .wide_out_resp_i  (wide_out_resp_i[KULCLUSTERIDX])
  );


`endif

`ifdef TARGET_ETHCLUSTER

  chimera_cluster_ethcluster #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(ETHCLUSTERIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_ethcluster (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[ETHCLUSTERIDX]),
    .rst_ni             (rst_ni[ETHCLUSTERIDX]),
    .widemem_bypass_i   (widemem_bypass_i[ETHCLUSTERIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(ETHCLUSTERIDX)+:`NRCORES(ETHCLUSTERIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(ETHCLUSTERIDX)+:`NRCORES(ETHCLUSTERIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(ETHCLUSTERIDX)+:`NRCORES(ETHCLUSTERIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(ETHCLUSTERIDX)+:`NRCORES(ETHCLUSTERIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(ETHCLUSTERIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[ETHCLUSTERIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[ETHCLUSTERIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[ETHCLUSTERIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*ETHCLUSTERIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*ETHCLUSTERIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[ETHCLUSTERIDX]),
    .wide_out_resp_i  (wide_out_resp_i[ETHCLUSTERIDX])
  );

`else

  chimera_cluster #(
    .Cfg              (Cfg),
    .NrCores          (`NRCORES(ETHCLUSTERIDX)),
    .narrow_in_req_t  (narrow_in_req_t),
    .narrow_in_resp_t (narrow_in_resp_t),
    .narrow_out_req_t (narrow_out_req_t),
    .narrow_out_resp_t(narrow_out_resp_t),
    .wide_out_req_t   (wide_out_req_t),
    .wide_out_resp_t  (wide_out_resp_t)
  ) i_chimera_cluster_4 (
    .soc_clk_i          (soc_clk_i),
    .clu_clk_i          (clu_clk_i[ETHCLUSTERIDX]),
    .rst_ni             (rst_ni[ETHCLUSTERIDX]),
    .widemem_bypass_i   (widemem_bypass_i[ETHCLUSTERIDX]),
    .debug_req_i        (debug_req_i[`PREVNRCORES(ETHCLUSTERIDX)+:`NRCORES(ETHCLUSTERIDX)]),
    .meip_i             (xeip_i[`PREVNRCORES(ETHCLUSTERIDX)+:`NRCORES(ETHCLUSTERIDX)]),
    .mtip_i             (mtip_i[`PREVNRCORES(ETHCLUSTERIDX)+:`NRCORES(ETHCLUSTERIDX)]),
    .msip_i             (msip_i[`PREVNRCORES(ETHCLUSTERIDX)+:`NRCORES(ETHCLUSTERIDX)]),
    .hart_base_id_i     (10'(`PREVNRCORES(ETHCLUSTERIDX) + 1)),
    .cluster_base_addr_i(Cfg.ChsCfg.AxiExtRegionStart[ETHCLUSTERIDX][Cfg.ChsCfg.AddrWidth-1:0]),
    .boot_addr_i        (boot_addr_i),

    .narrow_in_req_i  (narrow_in_req_i[ETHCLUSTERIDX]),
    .narrow_in_resp_o (narrow_in_resp_o[ETHCLUSTERIDX]),
    .narrow_out_req_o (narrow_out_req_o[2*ETHCLUSTERIDX+:2]),
    .narrow_out_resp_i(narrow_out_resp_i[2*ETHCLUSTERIDX+:2]),
    .wide_out_req_o   (wide_out_req_o[ETHCLUSTERIDX]),
    .wide_out_resp_i  (wide_out_resp_i[ETHCLUSTERIDX])
  );


`endif


endmodule
