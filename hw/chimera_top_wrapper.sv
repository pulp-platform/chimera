// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Moritz Scherer <scheremo@iis.ee.ethz.ch>

module chimera_top_wrapper
  import cheshire_pkg::*;
  import chimera_pkg::*;
  import chimera_reg_pkg::*;
#(
  parameter int unsigned SelectedCfg = 0
) (
  input  logic                        soc_clk_i,
  input  logic                        clu_clk_i,
  input  logic                        rst_ni,
  input  logic                        test_mode_i,
  input  logic      [            1:0] boot_mode_i,
  input  logic                        rtc_i,
  // JTAG interface
  input  logic                        jtag_tck_i,
  input  logic                        jtag_trst_ni,
  input  logic                        jtag_tms_i,
  input  logic                        jtag_tdi_i,
  output logic                        jtag_tdo_o,
  output logic                        jtag_tdo_oe_o,
  // UART interface
  output logic                        uart_tx_o,
  input  logic                        uart_rx_i,
  // UART modem flow control
  output logic                        uart_rts_no,
  output logic                        uart_dtr_no,
  input  logic                        uart_cts_ni,
  input  logic                        uart_dsr_ni,
  input  logic                        uart_dcd_ni,
  input  logic                        uart_rin_ni,
  // I2C interface
  output logic                        i2c_sda_o,
  input  logic                        i2c_sda_i,
  output logic                        i2c_sda_en_o,
  output logic                        i2c_scl_o,
  input  logic                        i2c_scl_i,
  output logic                        i2c_scl_en_o,
  // SPI host interface
  output logic                        spih_sck_o,
  output logic                        spih_sck_en_o,
  output logic      [  SpihNumCs-1:0] spih_csb_o,
  output logic      [  SpihNumCs-1:0] spih_csb_en_o,
  output logic      [            3:0] spih_sd_o,
  output logic      [            3:0] spih_sd_en_o,
  input  logic      [            3:0] spih_sd_i,
  // GPIO interface
  input  logic      [           31:0] gpio_i,
  output logic      [           31:0] gpio_o,
  output logic      [           31:0] gpio_en_o,
  // APB interface
  input  apb_resp_t                   apb_rsp_i,
  output apb_req_t                    apb_req_o,
  // PMU  Clusters control signals
  input  logic      [ExtClusters-1:0] pmu_rst_clusters_ni,
  input  logic      [ExtClusters-1:0] pmu_clkgate_en_clusters_i,  // TODO: lleone
  input  logic      [ExtClusters-1:0] pmu_iso_en_clusters_i,
  output logic      [ExtClusters-1:0] pmu_iso_ack_clusters_o

);

  `include "common_cells/registers.svh"
  `include "common_cells/assertions.svh"
  `include "cheshire/typedef.svh"

  // Cheshire config
  localparam cheshire_cfg_t Cfg = ChimeraCfg[SelectedCfg];
  `CHESHIRE_TYPEDEF_ALL(, Cfg)

  localparam type axi_wide_mst_req_t = mem_isl_wide_axi_mst_req_t;
  localparam type axi_wide_mst_rsp_t = mem_isl_wide_axi_mst_rsp_t;
  localparam type axi_wide_slv_req_t = mem_isl_wide_axi_slv_req_t;
  localparam type axi_wide_slv_rsp_t = mem_isl_wide_axi_slv_rsp_t;

  chimera_reg2hw_t reg2hw;

  // External AXI crossbar ports
  axi_mst_req_t [iomsb(Cfg.AxiExtNumMst):0] axi_mst_req;
  axi_mst_rsp_t [iomsb(Cfg.AxiExtNumMst):0] axi_mst_rsp;
  axi_wide_mst_req_t [iomsb(Cfg.AxiExtNumWideMst):0] axi_wide_mst_req;
  axi_wide_mst_rsp_t [iomsb(Cfg.AxiExtNumWideMst):0] axi_wide_mst_rsp;
  axi_slv_req_t [iomsb(Cfg.AxiExtNumSlv):0] axi_slv_req;
  axi_slv_rsp_t [iomsb(Cfg.AxiExtNumSlv):0] axi_slv_rsp;

  // External reg demux slaves
  reg_req_t [iomsb(Cfg.RegExtNumSlv):0] reg_slv_req;
  reg_rsp_t [iomsb(Cfg.RegExtNumSlv):0] reg_slv_rsp;

  // Interrupts from and to clusters
  logic [iomsb(Cfg.NumExtInIntrs):0] intr_ext_in;
  logic [iomsb(Cfg.NumExtOutIntrTgts):0][iomsb(Cfg.NumExtOutIntrs):0] intr_ext_out;

  // Interrupt requests to cluster cores
  logic [iomsb(NumIrqCtxts*Cfg.NumExtIrqHarts):0] xeip_ext;
  logic [iomsb(Cfg.NumExtIrqHarts):0] mtip_ext;
  logic [iomsb(Cfg.NumExtIrqHarts):0] msip_ext;

  // Debug interface to cluster cores
  logic dbg_active;
  logic [iomsb(Cfg.NumExtDbgHarts):0] dbg_ext_req;
  logic [iomsb(Cfg.NumExtDbgHarts):0] dbg_ext_unavail;

  cheshire_soc #(
    .Cfg                   (Cfg),
    .ExtHartinfo           ('0),
    .axi_ext_llc_req_t     (axi_mst_req_t),
    .axi_ext_llc_rsp_t     (axi_mst_rsp_t),
    .axi_ext_mst_req_t     (axi_mst_req_t),
    .axi_ext_mst_rsp_t     (axi_mst_rsp_t),
    .axi_ext_wide_mst_req_t(axi_wide_mst_req_t),
    .axi_ext_wide_mst_rsp_t(axi_wide_mst_rsp_t),
    .axi_ext_slv_req_t     (axi_slv_req_t),
    .axi_ext_slv_rsp_t     (axi_slv_rsp_t),
    .reg_ext_req_t         (reg_req_t),
    .reg_ext_rsp_t         (reg_rsp_t)
  ) i_cheshire (
    .clk_i                 (soc_clk_i),
    .rst_ni,
    .test_mode_i,
    .boot_mode_i,
    .rtc_i,
    // External AXI LLC (DRAM) port
    .axi_llc_mst_req_o     (),
    .axi_llc_mst_rsp_i     ('0),
    // External AXI crossbar ports
    .axi_ext_mst_req_i     (axi_mst_req),
    .axi_ext_mst_rsp_o     (axi_mst_rsp),
    .axi_ext_wide_mst_req_i(axi_wide_mst_req),
    .axi_ext_wide_mst_rsp_o(axi_wide_mst_rsp),
    .axi_ext_slv_req_o     (axi_slv_req),
    .axi_ext_slv_rsp_i     (axi_slv_rsp),
    // External reg demux slaves
    .reg_ext_slv_req_o     (reg_slv_req),
    .reg_ext_slv_rsp_i     (reg_slv_rsp),
    // Interrupts from and to external targets
    .intr_ext_i            (intr_ext_in),
    .intr_ext_o            (intr_ext_out),
    // Interrupt requests to external harts
    .xeip_ext_o            (xeip_ext),
    .mtip_ext_o            (mtip_ext),
    .msip_ext_o            (msip_ext),
    // Debug interface to external harts
    .dbg_active_o          (dbg_active),
    .dbg_ext_req_o         (dbg_ext_req),
    .dbg_ext_unavail_i     (dbg_ext_unavail),
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
    .slink_rcv_clk_i       ('0),
    .slink_rcv_clk_o       (),
    .slink_i               ('0),
    .slink_o               (),
    // VGA interface
    .vga_hsync_o           (),
    .vga_vsync_o           (),
    .vga_red_o             (),
    .vga_green_o           (),
    .vga_blue_o            (),
    .usb_clk_i             ('0),
    .usb_rst_ni            ('1),
    .usb_dm_i              ('0),
    .usb_dm_o              (),
    .usb_dm_oe_o           (),
    .usb_dp_i              ('0),
    .usb_dp_o              (),
    .usb_dp_oe_o           ()
  );


  // External REGs
  reg_to_apb #(
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t),
    .apb_req_t(apb_req_t),
    .apb_rsp_t(apb_resp_t)
  ) i_ext_reg_to_apb (
    .clk_i    (soc_clk_i),
    .rst_ni   (rst_ni),
    .reg_req_i(reg_slv_req[ExtCfgRegsIdx]),
    .reg_rsp_o(reg_slv_rsp[ExtCfgRegsIdx]),
    .apb_req_o(apb_req_o),
    .apb_rsp_i(apb_rsp_i)
  );


  // TOP-LEVEL REG

  chimera_reg_top #(
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t)
  ) i_reg_top (
    .clk_i    (soc_clk_i),
    .rst_ni,
    .reg_req_i(reg_slv_req[TopLevelCfgRegsIdx]),
    .reg_rsp_o(reg_slv_rsp[TopLevelCfgRegsIdx]),
    .reg2hw   (reg2hw),
    .devmode_i('1)
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
  assign wide_mem_bypass_mode = {
    reg2hw.wide_mem_cluster_4_bypass.q,
    reg2hw.wide_mem_cluster_3_bypass.q,
    reg2hw.wide_mem_cluster_2_bypass.q,
    reg2hw.wide_mem_cluster_1_bypass.q,
    reg2hw.wide_mem_cluster_0_bypass.q
  };

  logic [ExtClusters-1:0] cluster_clock_gate_en;
  logic [ExtClusters-1:0] clu_clk_gated;
  assign cluster_clock_gate_en = {
    reg2hw.cluster_4_clk_gate_en,
    reg2hw.cluster_3_clk_gate_en,
    reg2hw.cluster_2_clk_gate_en,
    reg2hw.cluster_1_clk_gate_en,
    reg2hw.cluster_0_clk_gate_en
  };

  for (genvar extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++) begin : gen_clk_gates
    tc_clk_gating i_cluster_clk_gate (
      .clk_i    (clu_clk_i),
      .en_i     (~cluster_clock_gate_en[extClusterIdx]),
      .test_en_i(1'b0),
      .clk_o    (clu_clk_gated[extClusterIdx])
    );
  end

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
    .rst_sync_ni      (pmu_rst_clusters_ni),
    .widemem_bypass_i (wide_mem_bypass_mode),
    .debug_req_i      (dbg_ext_req),
    .xeip_i           (xeip_ext),
    .mtip_i           (mtip_ext),
    .msip_i           (msip_ext),
    .narrow_in_req_i  (axi_slv_req),
    .narrow_in_resp_o (axi_slv_rsp),
    .narrow_out_req_o (axi_mst_req),
    .narrow_out_resp_i(axi_mst_rsp),
    .wide_out_req_o   (axi_wide_mst_req),
    .wide_out_resp_i  (axi_wide_mst_rsp),
    .isolate_i        (pmu_iso_en_clusters_i),
    .isolate_o        (pmu_iso_ack_clusters_o)
  );

endmodule
