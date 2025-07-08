// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
// Arpan Prasad <prasadar@iis.ee.ethz.ch>

module chimera_top_wrapper
  import cheshire_pkg::*;
  import chimera_pkg::*;
  import chimera_reg_pkg::*;
#(
  parameter int unsigned SelectedCfg = 0
) (
  input  logic                                         soc_clk_i,
  input  logic                                         clu_clk_i,
  input  logic                                         rst_ni,
  input  logic                                         test_mode_i,
  input  logic      [            1:0]                  boot_mode_i,
  input  logic                                         rtc_i,
  // JTAG interface
  input  logic                                         jtag_tck_i,
  input  logic                                         jtag_trst_ni,
  input  logic                                         jtag_tms_i,
  input  logic                                         jtag_tdi_i,
  output logic                                         jtag_tdo_o,
  output logic                                         jtag_tdo_oe_o,
  // UART interface
  output logic                                         uart_tx_o,
  input  logic                                         uart_rx_i,
  // UART modem flow control
  output logic                                         uart_rts_no,
  output logic                                         uart_dtr_no,
  input  logic                                         uart_cts_ni,
  input  logic                                         uart_dsr_ni,
  input  logic                                         uart_dcd_ni,
  input  logic                                         uart_rin_ni,
  // I2C interface
  output logic                                         i2c_sda_o,
  input  logic                                         i2c_sda_i,
  output logic                                         i2c_sda_en_o,
  output logic                                         i2c_scl_o,
  input  logic                                         i2c_scl_i,
  output logic                                         i2c_scl_en_o,
  // SPI host interface
  output logic                                         spih_sck_o,
  output logic                                         spih_sck_en_o,
  output logic      [  SpihNumCs-1:0]                  spih_csb_o,
  output logic      [  SpihNumCs-1:0]                  spih_csb_en_o,
  output logic      [            3:0]                  spih_sd_o,
  output logic      [            3:0]                  spih_sd_en_o,
  input  logic      [            3:0]                  spih_sd_i,
  // GPIO interface
  input  logic      [           31:0]                  gpio_i,
  output logic      [           31:0]                  gpio_o,
  output logic      [           31:0]                  gpio_en_o,
  // Hyperbus interface
  output logic      [ HypNumPhys-1:0][HypNumChips-1:0] hyper_cs_no,
  output logic      [ HypNumPhys-1:0]                  hyper_ck_o,
  output logic      [ HypNumPhys-1:0]                  hyper_ck_no,
  output logic      [ HypNumPhys-1:0]                  hyper_rwds_o,
  input  logic      [ HypNumPhys-1:0]                  hyper_rwds_i,
  output logic      [ HypNumPhys-1:0]                  hyper_rwds_oe_o,
  input  logic      [ HypNumPhys-1:0][            7:0] hyper_dq_i,
  output logic      [ HypNumPhys-1:0][            7:0] hyper_dq_o,
  output logic      [ HypNumPhys-1:0]                  hyper_dq_oe_o,
  output logic      [ HypNumPhys-1:0]                  hyper_reset_no,
  // APB interface
  input  apb_resp_t                                    apb_rsp_i,
  output apb_req_t                                     apb_req_o,
  // PMU  Clusters control signals
  input  logic      [ExtClusters-1:0]                  pmu_rst_clusters_ni,
  input  logic      [ExtClusters-1:0]                  pmu_clkgate_en_clusters_i,  // TODO: lleone
  input  logic      [ExtClusters-1:0]                  pmu_iso_en_clusters_i,
  output logic      [ExtClusters-1:0]                  pmu_iso_ack_clusters_o

);

  `include "common_cells/registers.svh"
  `include "common_cells/assertions.svh"
  `include "cheshire/typedef.svh"
  `include "chimera/typedef.svh"

  // Cheshire config
  localparam chimera_cfg_t Cfg = ChimeraCfg[SelectedCfg];
  localparam cheshire_cfg_t ChsCfg = Cfg.ChsCfg;

  `CHESHIRE_TYPEDEF_ALL(, ChsCfg)
  `CHIMERA_TYPEDEF_ALL(, Cfg)

  localparam type axi_wide_mst_req_t = mem_isl_wide_axi_mst_req_t;
  localparam type axi_wide_mst_rsp_t = mem_isl_wide_axi_mst_rsp_t;
  localparam type axi_wide_slv_req_t = mem_isl_wide_axi_slv_req_t;
  localparam type axi_wide_slv_rsp_t = mem_isl_wide_axi_slv_rsp_t;

  chimera_regs__out_t reg2hw;
  apb_resp_t apb_reg_soc_rsp;
  apb_req_t apb_reg_soc_req;

  // External AXI crossbar ports
  axi_mst_req_t [iomsb(ChsCfg.AxiExtNumMst):0] axi_mst_req;
  axi_mst_rsp_t [iomsb(ChsCfg.AxiExtNumMst):0] axi_mst_rsp;
  axi_wide_mst_req_t [iomsb(ChsCfg.AxiExtNumWideMst):0] axi_wide_mst_req;
  axi_wide_mst_rsp_t [iomsb(ChsCfg.AxiExtNumWideMst):0] axi_wide_mst_rsp;
  axi_slv_req_t [iomsb(ChsCfg.AxiExtNumSlv):0] axi_slv_req;
  axi_slv_rsp_t [iomsb(ChsCfg.AxiExtNumSlv):0] axi_slv_rsp;

  // External reg demux slaves
  reg_req_t [iomsb(ChsCfg.RegExtNumSlv):0] reg_slv_req;
  reg_rsp_t [iomsb(ChsCfg.RegExtNumSlv):0] reg_slv_rsp;

  // Interrupts from and to clusters
  logic [iomsb(ChsCfg.NumExtInIntrs):0] intr_ext_in;
  logic [iomsb(ChsCfg.NumExtOutIntrTgts):0][iomsb(ChsCfg.NumExtOutIntrs):0] intr_ext_out;

  // Interrupt requests to cluster cores
  logic [iomsb(NumIrqCtxts*ChsCfg.NumExtIrqHarts):0] xeip_ext;
  logic [iomsb(ChsCfg.NumExtIrqHarts):0] mtip_ext;
  logic [iomsb(ChsCfg.NumExtIrqHarts):0] msip_ext;

  // Debug interface to cluster cores
  logic dbg_active;
  logic [iomsb(ChsCfg.NumExtDbgHarts):0] dbg_ext_req;
  logic [iomsb(ChsCfg.NumExtDbgHarts):0] dbg_ext_unavail;

  // ---------------------------------------
  // |         Cheshire SoC                |
  // ---------------------------------------

  cheshire_soc #(
    .Cfg              (ChsCfg),
    .ExtHartinfo      ('0),
    .axi_ext_llc_req_t(axi_mst_req_t),
    .axi_ext_llc_rsp_t(axi_mst_rsp_t),
    .axi_ext_mst_req_t(axi_mst_req_t),
    .axi_ext_mst_rsp_t(axi_mst_rsp_t),
    // lleone: TODO: remove from here
    // .axi_ext_wide_mst_req_t(axi_wide_mst_req_t),
    // .axi_ext_wide_mst_rsp_t(axi_wide_mst_rsp_t),
    .axi_ext_slv_req_t(axi_slv_req_t),
    .axi_ext_slv_rsp_t(axi_slv_rsp_t),
    .reg_ext_req_t    (reg_req_t),
    .reg_ext_rsp_t    (reg_rsp_t)
  ) i_cheshire (
    .clk_i            (soc_clk_i),
    .rst_ni,
    .test_mode_i,
    .boot_mode_i,
    .rtc_i,
    // External AXI LLC (DRAM) port
    .axi_llc_mst_req_o(),
    .axi_llc_mst_rsp_i('0),
    // External AXI crossbar ports
    .axi_ext_mst_req_i(axi_mst_req),
    .axi_ext_mst_rsp_o(axi_mst_rsp),
    // lleone: TOOD: delet wide ports
    // .axi_ext_wide_mst_req_i(axi_wide_mst_req),
    // .axi_ext_wide_mst_rsp_o(axi_wide_mst_rsp),
    .axi_ext_slv_req_o(axi_slv_req),
    .axi_ext_slv_rsp_i(axi_slv_rsp),
    // External reg demux slaves
    .reg_ext_slv_req_o(reg_slv_req),
    .reg_ext_slv_rsp_i(reg_slv_rsp),
    // Interrupts from and to external targets
    .intr_ext_i       (intr_ext_in),
    .intr_ext_o       (intr_ext_out),
    // Interrupt requests to external harts
    .xeip_ext_o       (xeip_ext),
    .mtip_ext_o       (mtip_ext),
    .msip_ext_o       (msip_ext),
    // Debug interface to external harts
    .dbg_active_o     (dbg_active),
    .dbg_ext_req_o    (dbg_ext_req),
    .dbg_ext_unavail_i(dbg_ext_unavail),
    // JTAG interface
    .jtag_tck_i,
    .jtag_trst_ni,
    .jtag_tms_i,
    .jtag_tdi_i,
    .jtag_tdo_o,
    .jtag_tdo_oe_o,
    // UART interface
    .uart_tx_o,
    .uart_rx_i,
    // UART modem flow control
    .uart_rts_no,
    .uart_dtr_no,
    .uart_cts_ni,
    .uart_dsr_ni,
    .uart_dcd_ni,
    .uart_rin_ni,
    // I2C interface
    .i2c_sda_o,
    .i2c_sda_i,
    .i2c_sda_en_o,
    .i2c_scl_o,
    .i2c_scl_i,
    .i2c_scl_en_o,
    // SPI host interface
    .spih_sck_o,
    .spih_sck_en_o,
    .spih_csb_o,
    .spih_csb_en_o,
    .spih_sd_o,
    .spih_sd_en_o,
    .spih_sd_i,
    // GPIO interface
    .gpio_i,
    .gpio_o,
    .gpio_en_o,
    // Serial link interface
    .slink_rcv_clk_i  ('0),
    .slink_rcv_clk_o  (),
    .slink_i          ('0),
    .slink_o          (),
    // VGA interface
    .vga_hsync_o      (),
    .vga_vsync_o      (),
    .vga_red_o        (),
    .vga_green_o      (),
    .vga_blue_o       (),
    .usb_clk_i        ('0),
    .usb_rst_ni       ('1),
    .usb_dm_i         ('0),
    .usb_dm_o         (),
    .usb_dm_oe_o      (),
    .usb_dp_i         ('0),
    .usb_dp_o         (),
    .usb_dp_oe_o      ()
  );


  // External REGs
  reg_to_apb #(
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t),
    .apb_req_t(apb_req_t),
    .apb_rsp_t(apb_resp_t)
  ) i_soc_reg_to_apb (
    .clk_i    (soc_clk_i),
    .rst_ni   (rst_ni),
    .reg_req_i(reg_slv_req[ExtCfgRegsIdx]),
    .reg_rsp_o(reg_slv_rsp[ExtCfgRegsIdx]),
    .apb_req_o(apb_req_o),
    .apb_rsp_i(apb_rsp_i)
  );

  // TOP-LEVEL REG
  reg_to_apb #(
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t),
    .apb_req_t(apb_req_t),
    .apb_rsp_t(apb_resp_t)
  ) i_ext_reg_to_apb (
    .clk_i    (soc_clk_i),
    .rst_ni   (rst_ni),
    .reg_req_i(reg_slv_req[TopLevelCfgRegsIdx]),
    .reg_rsp_o(reg_slv_rsp[TopLevelCfgRegsIdx]),
    .apb_req_o(apb_reg_soc_req),
    .apb_rsp_i(apb_reg_soc_rsp)
  );

  chimera_reg_top i_reg_top (
    .clk          (soc_clk_i),
    .arst_n       (rst_ni),
    .s_apb_psel   (apb_reg_soc_req.psel),
    .s_apb_penable(apb_reg_soc_req.penable),
    .s_apb_pwrite (apb_reg_soc_req.pwrite),
    .s_apb_pprot  (apb_reg_soc_req.pprot),
    .s_apb_paddr  (apb_reg_soc_req.paddr[CHIMERA_REG_TOP_MIN_ADDR_WIDTH-1:0]),
    .s_apb_pwdata (apb_reg_soc_req.pwdata),
    .s_apb_pstrb  (apb_reg_soc_req.pstrb),
    .s_apb_pready (apb_reg_soc_rsp.pready),
    .s_apb_prdata (apb_reg_soc_rsp.prdata),
    .s_apb_pslverr(apb_reg_soc_rsp.pslverr),
    .hwif_out     (reg2hw)
  );


  // SNITCH BOOTROM

  logic [31:0] snitch_bootrom_addr;
  logic [31:0] snitch_bootrom_data, snitch_bootrom_data_q;
  logic snitch_bootrom_req, snitch_bootrom_req_q;
  logic snitch_bootrom_we, snitch_bootrom_we_q;

  // Delay response by one cycle to fulfill mem protocol

  `FF(snitch_bootrom_data_q, snitch_bootrom_data, '0, soc_clk_i, rst_ni)
  `FF(snitch_bootrom_req_q, snitch_bootrom_req, '0, soc_clk_i, rst_ni)
  `FF(snitch_bootrom_we_q, snitch_bootrom_we, '0, soc_clk_i, rst_ni)

  reg_to_mem #(
    .AW   (32),
    .DW   (32),
    .req_t(reg_req_t),
    .rsp_t(reg_rsp_t)
  ) i_reg_to_snitch_bootrom (
    .clk_i    (soc_clk_i),
    .rst_ni,
    .reg_req_i(reg_slv_req[SnitchBootROMIdx]),
    .reg_rsp_o(reg_slv_rsp[SnitchBootROMIdx]),
    .req_o    (snitch_bootrom_req),
    .gnt_i    (snitch_bootrom_req),
    .we_o     (snitch_bootrom_we),
    .addr_o   (snitch_bootrom_addr),
    .wdata_o  (),
    .wstrb_o  (),
    .rdata_i  (snitch_bootrom_data_q),
    .rvalid_i (snitch_bootrom_req_q),
    .rerror_i (snitch_bootrom_we_q)
  );

  snitch_bootrom #(
    .AddrWidth(32),
    .DataWidth(32)
  ) i_snitch_bootrom (
    .clk_i (soc_clk_i),
    .rst_ni,
    .req_i (snitch_bootrom_req),
    .addr_i(snitch_bootrom_addr),
    .data_o(snitch_bootrom_data)
  );

  logic [ExtClusters-1:0] wide_mem_bypass_mode;
  for (
      genvar extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++
  ) begin : gen_wide_mem_bypass
    assign wide_mem_bypass_mode[extClusterIdx] =
           reg2hw.wide_mem_cluster_bypass[extClusterIdx].WIDE_MEM_CLUSTER_BYPASS.value;
  end

  logic [ExtClusters-1:0] cluster_clock_gate_en;
  logic [ExtClusters-1:0] clu_clk_gated;
  for (genvar extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++) begin : gen_clk_gates
    assign cluster_clock_gate_en[extClusterIdx] =
           reg2hw.cluster_clk_gate_en[extClusterIdx].CLUSTER_CLK_GATE_EN.value;

    tc_clk_gating i_cluster_clk_gate (
      .clk_i    (clu_clk_i),
      .en_i     (~cluster_clock_gate_en[extClusterIdx]),
      .test_en_i(1'b0),
      .clk_o    (clu_clk_gated[extClusterIdx])
    );
  end

  logic [ExtClusters-1:0] cluster_rst_n;
  logic [ExtClusters-1:0] cluster_soft_rst_n;
  for (genvar extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++) begin : gen_soft_rst
    assign cluster_soft_rst_n[extClusterIdx] =
           ~reg2hw.reset_cluster[extClusterIdx].RESET_CLUSTER.value;
  end

  // The Rst used for each cluster is the AND gate among all different source of rst in the system that are:
  // - rst_ni: Global asynchronous reset coming from the PAD
  // - cluster_soft_rst_n: Software synchronous rst coming from the SoC configuration registers
  // - pmu_rst_clusters_ni: PMU Synchronous rst for power management
  assign cluster_rst_n = cluster_soft_rst_n & pmu_rst_clusters_ni & {ExtClusters{rst_ni}};


  // ---------------------------------------
  // |        Clusters Domain              |
  // ---------------------------------------
  chimera_clu_domain #(
    .Cfg              (Cfg),
    .narrow_in_req_t  (axi_slv_req_t),
    .narrow_in_resp_t (axi_slv_rsp_t),
    .narrow_out_req_t (axi_mst_req_t),
    .narrow_out_resp_t(axi_mst_rsp_t),
    .wide_out_req_t   (axi_wide_mst_req_t),
    .wide_out_resp_t  (axi_wide_mst_rsp_t)
  ) i_cluster_domain (
    .soc_clk_i        (soc_clk_i),
    .clu_clk_i        (clu_clk_gated),
    .rst_ni           (cluster_rst_n),
    .widemem_bypass_i (wide_mem_bypass_mode),
    .boot_addr_i      (reg2hw.snitch_configurable_boot_addr.SNITCH_CONFIGURABLE_BOOT_ADDR.value),
    .debug_req_i      (dbg_ext_req),
    .xeip_i           (xeip_ext),
    .mtip_i           (mtip_ext),
    .msip_i           (msip_ext),
    .narrow_in_req_i  (axi_slv_req[ClusterIdx[0]+:ExtClusters]),
    .narrow_in_resp_o (axi_slv_rsp[ClusterIdx[0]+:ExtClusters]),
    .narrow_out_req_o (axi_mst_req),
    .narrow_out_resp_i(axi_mst_rsp),
    .wide_out_req_o   (axi_wide_mst_req),
    .wide_out_resp_i  (axi_wide_mst_rsp),
    .isolate_i        (pmu_iso_en_clusters_i),
    .isolate_o        (pmu_iso_ack_clusters_o)
  );

  // Generate indices and get maps for all ports
  localparam axi_in_t AxiIn = gen_axi_in(ChsCfg);
  localparam axi_out_t AxiOut = gen_axi_out(ChsCfg);

  // ---------------------------------------
  // |          Memory Island              |
  // ---------------------------------------

  chimera_memisland_domain #(
    .Cfg             (Cfg),
    .NumWideMst      (ChsCfg.AxiExtNumWideMst),
    .axi_narrow_req_t(axi_slv_req_t),
    .axi_narrow_rsp_t(axi_slv_rsp_t),
    .axi_wide_req_t  (axi_wide_mst_req_t),
    .axi_wide_rsp_t  (axi_wide_mst_rsp_t)
  ) i_memisland_domain (
    .clk_i           (soc_clk_i),
    .rst_ni,
    .axi_narrow_req_i(axi_slv_req[MemIslandIdx]),
    .axi_narrow_rsp_o(axi_slv_rsp[MemIslandIdx]),
    .axi_wide_req_i  (axi_wide_mst_req),
    .axi_wide_rsp_o  (axi_wide_mst_rsp)
  );

  localparam int unsigned AxiSlvIdWidth = ChsCfg.AxiMstIdWidth + $clog2(AxiIn.num_in);

  // Slave CDC parameters
  localparam int unsigned ChimeraAxiSlvAwWidth = (2 ** LogDepth) * axi_pkg::aw_width(
      ChsCfg.AddrWidth, AxiSlvIdWidth, ChsCfg.AxiUserWidth
  );
  localparam int unsigned ChimeraAxiSlvWWidth = (2 ** LogDepth) * axi_pkg::w_width(
      ChsCfg.AxiDataWidth, ChsCfg.AxiUserWidth
  );
  localparam int unsigned ChimeraAxiSlvBWidth = (2 ** LogDepth) * axi_pkg::b_width(
      AxiSlvIdWidth, ChsCfg.AxiUserWidth
  );
  localparam int unsigned ChimeraAxiSlvArWidth = (2 ** LogDepth) * axi_pkg::ar_width(
      ChsCfg.AddrWidth, AxiSlvIdWidth, ChsCfg.AxiUserWidth
  );
  localparam int unsigned ChimeraAxiSlvRWidth = (2 ** LogDepth) * axi_pkg::r_width(
      ChsCfg.AxiDataWidth, AxiSlvIdWidth, ChsCfg.AxiUserWidth
  );

  // Master CDC parameters
  localparam int unsigned ChimeraAxiMstAwWidth = (2 ** LogDepth) * axi_pkg::aw_width(
      ChsCfg.AddrWidth, ChsCfg.AxiMstIdWidth, ChsCfg.AxiUserWidth
  );
  localparam int unsigned ChimeraAxiMstWWidth = (2 ** LogDepth) * axi_pkg::w_width(
      ChsCfg.AxiDataWidth, ChsCfg.AxiUserWidth
  );
  localparam int unsigned ChimeraAxiMstBWidth = (2 ** LogDepth) * axi_pkg::b_width(
      ChsCfg.AxiMstIdWidth, ChsCfg.AxiUserWidth
  );
  localparam int unsigned ChimeraAxiMstArWidth = (2 ** LogDepth) * axi_pkg::ar_width(
      ChsCfg.AddrWidth, ChsCfg.AxiMstIdWidth, ChsCfg.AxiUserWidth
  );
  localparam int unsigned ChimeraAxiMstRWidth = (2 ** LogDepth) * axi_pkg::r_width(
      ChsCfg.AxiDataWidth, ChsCfg.AxiMstIdWidth, ChsCfg.AxiUserWidth
  );

  logic [ChimeraAxiSlvArWidth-1:0] hyper_ar_data;
  logic [              LogDepth:0] hyper_ar_wptr;
  logic [              LogDepth:0] hyper_ar_rptr;
  logic [ChimeraAxiSlvAwWidth-1:0] hyper_aw_data;
  logic [              LogDepth:0] hyper_aw_wptr;
  logic [              LogDepth:0] hyper_aw_rptr;
  logic [ ChimeraAxiSlvBWidth-1:0] hyper_b_data;
  logic [              LogDepth:0] hyper_b_wptr;
  logic [              LogDepth:0] hyper_b_rptr;
  logic [ ChimeraAxiSlvRWidth-1:0] hyper_r_data;
  logic [              LogDepth:0] hyper_r_wptr;
  logic [              LogDepth:0] hyper_r_rptr;
  logic [ ChimeraAxiSlvWWidth-1:0] hyper_w_data;
  logic [              LogDepth:0] hyper_w_wptr;
  logic [              LogDepth:0] hyper_w_rptr;

  axi_cdc_src #(
    .LogDepth  (LogDepth),
    .SyncStages(SyncStages),
    .aw_chan_t (axi_slv_aw_chan_t),
    .w_chan_t  (axi_slv_w_chan_t),
    .b_chan_t  (axi_slv_b_chan_t),
    .ar_chan_t (axi_slv_ar_chan_t),
    .r_chan_t  (axi_slv_r_chan_t),
    .axi_req_t (axi_slv_req_t),
    .axi_resp_t(axi_slv_rsp_t)
  ) hyperbus_slv_cdc_src (
    // synchronous slave port
    .src_clk_i                  (soc_clk_i),
    .src_rst_ni                 (rst_ni),
    .src_req_i                  (axi_slv_req[HyperbusIdx]),
    .src_resp_o                 (axi_slv_rsp[HyperbusIdx]),
    // asynchronous master port
    .async_data_master_aw_data_o(hyper_aw_data),
    .async_data_master_aw_wptr_o(hyper_aw_wptr),
    .async_data_master_aw_rptr_i(hyper_aw_rptr),
    .async_data_master_w_data_o (hyper_w_data),
    .async_data_master_w_wptr_o (hyper_w_wptr),
    .async_data_master_w_rptr_i (hyper_w_rptr),
    .async_data_master_b_data_i (hyper_b_data),
    .async_data_master_b_wptr_i (hyper_b_wptr),
    .async_data_master_b_rptr_o (hyper_b_rptr),
    .async_data_master_ar_data_o(hyper_ar_data),
    .async_data_master_ar_wptr_o(hyper_ar_wptr),
    .async_data_master_ar_rptr_i(hyper_ar_rptr),
    .async_data_master_r_data_i (hyper_r_data),
    .async_data_master_r_wptr_i (hyper_r_wptr),
    .async_data_master_r_rptr_o (hyper_r_rptr)
  );

  hyperbus_wrap #(
    .NumChips        (HypNumChips),
    .NumPhys         (HypNumPhys),
    .IsClockODelayed (1'b0),
    .AxiAddrWidth    (ChsCfg.AddrWidth),
    .AxiDataWidth    (ChsCfg.AxiDataWidth),
    .AxiIdWidth      (AxiSlvIdWidth),
    .AxiUserWidth    (ChsCfg.AxiUserWidth),
    .axi_req_t       (axi_slv_req_t),
    .axi_rsp_t       (axi_slv_rsp_t),
    .axi_w_chan_t    (axi_slv_w_chan_t),
    .axi_b_chan_t    (axi_slv_b_chan_t),
    .axi_ar_chan_t   (axi_slv_ar_chan_t),
    .axi_r_chan_t    (axi_slv_r_chan_t),
    .axi_aw_chan_t   (axi_slv_aw_chan_t),
    .RegAddrWidth    (ChsCfg.AddrWidth),
    .RegDataWidth    (ChsCfg.AxiDataWidth),
    .reg_req_t       (reg_req_t),
    .reg_rsp_t       (reg_rsp_t),
    .RxFifoLogDepth  (32'd2),
    .TxFifoLogDepth  (32'd2),
    .RstChipBase     (ChsCfg.LlcOutRegionStart),
    .RstChipSpace    (HyperbusRegionEnd - HyperbusRegionStart),
    .PhyStartupCycles(300 * 200),
    .AxiLogDepth     (LogDepth),
    .AxiSlaveArWidth (ChimeraAxiSlvArWidth),
    .AxiSlaveAwWidth (ChimeraAxiSlvAwWidth),
    .AxiSlaveBWidth  (ChimeraAxiSlvBWidth),
    .AxiSlaveRWidth  (ChimeraAxiSlvRWidth),
    .AxiSlaveWWidth  (ChimeraAxiSlvWWidth),
    .AxiMaxTrans     (ChsCfg.AxiMaxSlvTrans),
    .CdcSyncStages   (SyncStages)
  ) i_hyperbus_wrap (
    .clk_i              (soc_clk_i),
    .rst_ni             (rst_ni),
    .test_mode_i        (test_mode_i),
    .axi_slave_ar_data_i(hyper_ar_data),
    .axi_slave_ar_wptr_i(hyper_ar_wptr),
    .axi_slave_ar_rptr_o(hyper_ar_rptr),
    .axi_slave_aw_data_i(hyper_aw_data),
    .axi_slave_aw_wptr_i(hyper_aw_wptr),
    .axi_slave_aw_rptr_o(hyper_aw_rptr),
    .axi_slave_b_data_o (hyper_b_data),
    .axi_slave_b_wptr_o (hyper_b_wptr),
    .axi_slave_b_rptr_i (hyper_b_rptr),
    .axi_slave_r_data_o (hyper_r_data),
    .axi_slave_r_wptr_o (hyper_r_wptr),
    .axi_slave_r_rptr_i (hyper_r_rptr),
    .axi_slave_w_data_i (hyper_w_data),
    .axi_slave_w_wptr_i (hyper_w_wptr),
    .axi_slave_w_rptr_o (hyper_w_rptr),
    .rbus_req_addr_i    (reg_slv_req[HyperCfgRegsIdx].addr),
    .rbus_req_write_i   (reg_slv_req[HyperCfgRegsIdx].write),
    .rbus_req_wdata_i   (reg_slv_req[HyperCfgRegsIdx].wdata),
    .rbus_req_wstrb_i   (reg_slv_req[HyperCfgRegsIdx].wstrb),
    .rbus_req_valid_i   (reg_slv_req[HyperCfgRegsIdx].valid),
    .rbus_rsp_rdata_o   (reg_slv_rsp[HyperCfgRegsIdx].rdata),
    .rbus_rsp_ready_o   (reg_slv_rsp[HyperCfgRegsIdx].ready),
    .rbus_rsp_error_o   (reg_slv_rsp[HyperCfgRegsIdx].error),
    .hyper_cs_no,
    .hyper_ck_o,
    .hyper_ck_no,
    .hyper_rwds_o,
    .hyper_rwds_i,
    .hyper_rwds_oe_o,
    .hyper_dq_i,
    .hyper_dq_o,
    .hyper_dq_oe_o,
    .hyper_reset_no
  );
endmodule
