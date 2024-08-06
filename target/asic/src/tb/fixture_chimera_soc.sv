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

   import cheshire_pkg::*;
   import tb_cheshire_pkg::*;
   import chimera_pkg::*;

   localparam int unsigned   NumGpio = 32;
   localparam cheshire_cfg_t DutCfg = ChimeraCfg[SelectedCfg];

   `CHESHIRE_TYPEDEF_ALL(, DutCfg)


   ///////////
   //  DUT  //
   ///////////

   logic       soc_clk;
   logic       clu_clk;
   logic       rst_n;
   logic       test_mode;
   logic [1:0] boot_mode;
   logic       rtc;

   logic       jtag_tck;
   logic       jtag_trst_n;
   logic       jtag_tms;
   logic       jtag_tdi;
   logic       jtag_tdo;

   logic       uart_tx;
   logic       uart_rx;

   logic       i2c_sda_o;
   logic       i2c_sda_i;
   logic       i2c_sda_en;
   logic       i2c_scl_o;
   logic       i2c_scl_i;
   logic       i2c_scl_en;

   logic       spih_sck_o;
   logic       spih_sck_en;
   logic [SpihNumCs-1:0] spih_csb_o;
   logic [SpihNumCs-1:0] spih_csb_en;
   logic [ 3:0]		 spih_sd_o;
   logic [ 3:0]		 spih_sd_i;
   logic [ 3:0]		 spih_sd_en;

   logic [SlinkNumChan-1:0] slink_rcv_clk_i;
   logic [SlinkNumChan-1:0] slink_rcv_clk_o;
   logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_i;
   logic [SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_o;

   // Wire signals to connect with Chimera ports
   wire               w_soc_clk;
   wire               w_rst_n;
   wire               w_byp_sel_clk;
   wire               w_jtag_tck;
   wire               w_jtag_trst_n;
   wire               w_jtag_tms;
   wire               w_jtag_tdi;
   wire               w_jtag_tdo;
   wire               w_boot_mode_0;
   wire               w_boot_mode_1;
   wire [NumGpio-1:0] w_gpio;
   wire               xxxxxx;

   assign w_jtag_tms = jtag_tms;
   assign w_soc_clk = soc_clk;
   assign w_rst_n = rst_n;
   assign w_jtag_tck = jtag_tck;
   // assign w_jtag_tck = 1'b0;

   assign w_jtag_trst_n = jtag_trst_n;
   assign w_jtag_tms = jtag_tms;
   assign w_jtag_tdi = jtag_tdi;
   assign jtag_tdo = w_jtag_tdo;
   assign w_boot_mode_0 = boot_mode[0];
   assign w_boot_mode_1 = boot_mode[1];
   assign w_byp_sel_clk = 1'b0;
   assign w_gpio = '0;


   chimera #(
       .SelectedCfg(SelectedCfg)
       ) dut (

        .pad_aon_static_lse_clk_pad     (w_soc_clk),
        .pad_aon_static_hse_clk_pad     (w_soc_clk),
        .pad_aon_static_byp_sel_clk_pad (w_byp_sel_clk),
        .pad_aon_static_rstn_pad        (w_rst_n),
        .pad_aon_static_jtag_tck_pad    (w_jtag_tck),
        .pad_aon_static_jtag_trstn_pad  (w_jtag_trst_n),
        .pad_aon_static_jtag_tms_pad    (w_jtag_tms),
        .pad_aon_static_jtag_tdi_pad    (w_jtag_tdi),
        .pad_aon_static_jtag_tdo_pad    (w_jtag_tdo),
        .pad_aon_static_bootsel_0_pad   (w_boot_mode_0),
        .pad_aon_static_bootsel_1_pad   (w_boot_mode_1),
        .pad_aon_gpioa_gpio_0_pad       (w_gpio[0]),
        .pad_aon_gpioa_gpio_1_pad       (w_gpio[1]),
        .pad_aon_gpioa_gpio_2_pad       (w_gpio[2]),
        .pad_aon_gpioa_gpio_3_pad       (w_gpio[3]),
        .pad_aon_gpioa_gpio_4_pad       (w_gpio[4]),
        .pad_aon_gpioa_gpio_5_pad       (w_gpio[5]),
        .pad_aon_gpioa_gpio_6_pad       (w_gpio[6]),
        .pad_aon_gpioa_gpio_7_pad       (w_gpio[7]),
        .pad_aon_gpioa_gpio_8_pad       (w_gpio[8]),
        .pad_aon_gpioa_gpio_9_pad       (w_gpio[9]),
        .pad_aon_gpioa_gpio_10_pad      (w_gpio[10]),
        .pad_aon_gpioa_gpio_11_pad      (w_gpio[11]),
        .pad_aon_gpioa_gpio_12_pad      (w_gpio[12]),
        .pad_aon_gpioa_gpio_13_pad      (w_gpio[13]),
        .pad_aon_gpioa_gpio_14_pad      (w_gpio[14]),
        .pad_aon_gpioa_gpio_15_pad      (w_gpio[15]),
        .pad_aon_gpioa_gpio_16_pad      (w_gpio[16]),
        .pad_aon_gpioa_gpio_17_pad      (w_gpio[17]),
        .pad_aon_gpioa_gpio_18_pad      (w_gpio[18]),
        .pad_aon_gpioa_gpio_19_pad      (w_gpio[19]),
        .pad_aon_gpioa_gpio_20_pad      (w_gpio[20]),
        .pad_aon_gpioa_gpio_21_pad      (w_gpio[21]),
        .pad_aon_gpioa_gpio_22_pad      (w_gpio[22]),
        .pad_aon_gpioa_gpio_23_pad      (w_gpio[23]),
        .pad_aon_gpioa_gpio_24_pad      (w_gpio[24]),
        .pad_aon_gpioa_gpio_25_pad      (w_gpio[25]),
        .pad_aon_gpioa_gpio_26_pad      (w_gpio[26]),
        .pad_aon_gpioa_gpio_27_pad      (w_gpio[27]),
        .pad_aon_gpioa_gpio_28_pad      (w_gpio[28]),
        .pad_aon_gpioa_gpio_29_pad      (w_gpio[29]),
        .pad_aon_gpioa_gpio_30_pad      (w_gpio[30]),
        .pad_aon_gpioa_gpio_31_pad      (w_gpio[31])
        );

   ////////////////////////
   //  Tristate Adapter  //
   ////////////////////////

   wire i2c_sda;
   wire	i2c_scl;

   wire	spih_sck;
   wire [SpihNumCs-1:0]	spih_csb;
   wire [ 3:0]		spih_sd;

   vip_cheshire_soc_tristate vip_tristate (.*);

   ///////////
   //  VIP  //
   ///////////

   axi_mst_req_t axi_slink_mst_req;
   axi_mst_rsp_t axi_slink_mst_rsp;

   assign axi_slink_mst_req = '0;

   vip_chimera_soc #(
         .DutCfg            ( DutCfg ),
         .axi_ext_mst_req_t(axi_mst_req_t),
         .axi_ext_mst_rsp_t(axi_mst_rsp_t)
         ) vip (.*);

endmodule
