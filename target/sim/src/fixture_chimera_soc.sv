// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>

module fixture_chimera_soc #(
  /// The selected simulation configuration from the `tb_cheshire_pkg`.
  parameter int unsigned SelectedCfg = 32'd0

);

  `include "cheshire/typedef.svh"
  `include "chimera/typedef.svh"

  import cheshire_pkg::*;
  import tb_cheshire_pkg::*;
  import chimera_pkg::*;
  import tb_chimera_pkg::*;

  localparam chimera_cfg_t DutCfg = ChimeraCfg[SelectedCfg];
  localparam cheshire_cfg_t ChsCfg = DutCfg.ChsCfg;

  `CHESHIRE_TYPEDEF_ALL(, ChsCfg)
  `CHIMERA_TYPEDEF_ALL(, DutCfg)

  ///////////
  //  DUT  //
  ///////////

  logic                                   soc_clk;
  logic                                   clu_clk;
  logic                                   rst_n;
  logic                                   test_mode;
  logic [           1:0]                  boot_mode;
  logic                                   rtc;

  logic                                   jtag_tck;
  logic                                   jtag_trst_n;
  logic                                   jtag_tms;
  logic                                   jtag_tdi;
  logic                                   jtag_tdo;

  logic                                   uart_tx;
  logic                                   uart_rx;

  logic                                   i2c_sda_o;
  logic                                   i2c_sda_i;
  logic                                   i2c_sda_en;
  logic                                   i2c_scl_o;
  logic                                   i2c_scl_i;
  logic                                   i2c_scl_en;

  logic                                   spih_sck_o;
  logic                                   spih_sck_en;
  logic [ SpihNumCs-1:0]                  spih_csb_o;
  logic [ SpihNumCs-1:0]                  spih_csb_en;
  logic [           3:0]                  spih_sd_o;
  logic [           3:0]                  spih_sd_i;
  logic [           3:0]                  spih_sd_en;

  logic [HypNumPhys-1:0][HypNumChips-1:0] hyper_cs_no;
  logic [HypNumPhys-1:0]                  hyper_ck_i;
  logic [HypNumPhys-1:0]                  hyper_ck_o;
  logic [HypNumPhys-1:0]                  hyper_ck_ni;
  logic [HypNumPhys-1:0]                  hyper_ck_no;
  logic [HypNumPhys-1:0]                  hyper_rwds_o;
  logic [HypNumPhys-1:0]                  hyper_rwds_i;
  logic [HypNumPhys-1:0]                  hyper_rwds_oe_o;
  logic [HypNumPhys-1:0][            7:0] hyper_dq_i;
  logic [HypNumPhys-1:0][            7:0] hyper_dq_o;
  logic [HypNumPhys-1:0]                  hyper_dq_oe_o;
  logic [HypNumPhys-1:0]                  hyper_reset_no;

  wire  [HypNumPhys-1:0][HypNumChips-1:0] pad_hyper_csn;
  wire  [HypNumPhys-1:0]                  pad_hyper_ck;
  wire  [HypNumPhys-1:0]                  pad_hyper_ckn;
  wire  [HypNumPhys-1:0]                  pad_hyper_rwds;
  wire  [HypNumPhys-1:0]                  pad_hyper_resetn;
  wire  [HypNumPhys-1:0][            7:0] pad_hyper_dq;

  chimera_top_wrapper #(
    .SelectedCfg(SelectedCfg),
    .HypNumPhys (HypNumPhys),
    .HypNumChips(HypNumChips)
  ) dut (
    .soc_clk_i                (soc_clk),
    .clu_clk_i                (clu_clk),
    .rst_ni                   (rst_n),
    .test_mode_i              (test_mode),
    .boot_mode_i              (boot_mode),
    .rtc_i                    (rtc),
    .jtag_tck_i               (jtag_tck),
    .jtag_trst_ni             (jtag_trst_n),
    .jtag_tms_i               (jtag_tms),
    .jtag_tdi_i               (jtag_tdi),
    .jtag_tdo_o               (jtag_tdo),
    .jtag_tdo_oe_o            (),
    .uart_tx_o                (uart_tx),
    .uart_rx_i                (uart_rx),
    .uart_rts_no              (),
    .uart_dtr_no              (),
    .uart_cts_ni              (1'b0),
    .uart_dsr_ni              (1'b0),
    .uart_dcd_ni              (1'b0),
    .uart_rin_ni              (1'b0),
    .i2c_sda_o                (i2c_sda_o),
    .i2c_sda_i                (i2c_sda_i),
    .i2c_sda_en_o             (i2c_sda_en),
    .i2c_scl_o                (i2c_scl_o),
    .i2c_scl_i                (i2c_scl_i),
    .i2c_scl_en_o             (i2c_scl_en),
    .spih_sck_o               (spih_sck_o),
    .spih_sck_en_o            (spih_sck_en),
    .spih_csb_o               (spih_csb_o),
    .spih_csb_en_o            (spih_csb_en),
    .spih_sd_o                (spih_sd_o),
    .spih_sd_en_o             (spih_sd_en),
    .spih_sd_i                (spih_sd_i),
    .gpio_i                   ('0),
    .gpio_o                   (),
    .gpio_en_o                (),
    .hyper_cs_no              (hyper_cs_no),
    .hyper_ck_o               (hyper_ck_o),
    .hyper_ck_no              (hyper_ck_no),
    .hyper_rwds_o             (hyper_rwds_o),
    .hyper_rwds_i             (hyper_rwds_i),
    .hyper_rwds_oe_o          (hyper_rwds_oe_o),
    .hyper_dq_i               (hyper_dq_i),
    .hyper_dq_o               (hyper_dq_o),
    .hyper_dq_oe_o            (hyper_dq_oe_o),
    .hyper_reset_no           (hyper_reset_no),
    .pmu_rst_clusters_ni      ({ExtClusters{rst_n}}),
    .pmu_clkgate_en_clusters_i(),
    .pmu_iso_en_clusters_i    ('0),                    // Never Isolate
    .pmu_iso_ack_clusters_o   ()
  );

  ////////////////////////
  //  Tristate Adapter  //
  ////////////////////////

  wire                 i2c_sda;
  wire                 i2c_scl;

  wire                 spih_sck;
  wire [SpihNumCs-1:0] spih_csb;
  wire [          3:0] spih_sd;

  vip_cheshire_soc_tristate vip_tristate (.*);

  ///////////
  //  VIP  //
  ///////////

  vip_chimera_soc #(
    .DutCfg                (ChsCfg),
    // Determine whether we preload the hyperram model or not User preload. If 0, the memory model
    // is not preloaded at time 0.
    .HypUserPreload        (`HYP_USER_PRELOAD),
    // Mem files for hyperram model. The argument is considered only if HypUserPreload==1 in the
    // memory model.
    .Hyp0UserPreloadMemFile(`HYP0_PRELOAD_MEM_FILE),
    .Hyp1UserPreloadMemFile(`HYP1_PRELOAD_MEM_FILE),
    .axi_ext_mst_req_t     (axi_mst_req_t),
    .axi_ext_mst_rsp_t     (axi_mst_rsp_t)
  ) vip (
    .*
  );

endmodule
