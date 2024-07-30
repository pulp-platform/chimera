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

   chimera #(
	     .SelectedCfg(SelectedCfg)
	     ) dut (

		    .pad_aon_static_lse_clk_pad     (soc_clk),
		    .pad_aon_static_hse_clk_pad     (soc_clk),
		    .pad_aon_static_byp_sel_clk_pad ('0),
		    .pad_aon_static_rstn_pad        (rst_n),
		    .pad_aon_static_jtag_tck_pad    (jtag_tck),
		    .pad_aon_static_jtag_trstn_pad  (jtag_trst_n),
		    .pad_aon_static_jtag_tms_pad    (jtag_tms),
		    .pad_aon_static_jtag_tdi_pad    (jtag_tdi),
		    .pad_aon_static_jtag_tdo_pad    (jtag_tdo),
		    .pad_aon_static_bootsel_pad     (boot_mode),
		    .pad_aon_gpioa_gpio_0_pad       (),
		    .pad_aon_gpioa_gpio_1_pad       (),
		    .pad_aon_gpioa_gpio_2_pad	    (),
		    .pad_aon_gpioa_gpio_3_pad	    (),
		    .pad_aon_gpioa_gpio_4_pad	    (),
		    .pad_aon_gpioa_gpio_5_pad	    (),
		    .pad_aon_gpioa_gpio_6_pad	    (),
		    .pad_aon_gpioa_gpio_7_pad	    (),
		    .pad_aon_gpioa_gpio_8_pad	    (),
		    .pad_aon_gpioa_gpio_9_pad       (),
		    .pad_aon_gpioa_gpio_10_pad	    (),
		    .pad_aon_gpioa_gpio_11_pad	    (),
		    .pad_aon_gpioa_gpio_12_pad	    (),
		    .pad_aon_gpioa_gpio_13_pad	    (),
		    .pad_aon_gpioa_gpio_14_pad	    (),
		    .pad_aon_gpioa_gpio_15_pad	    (),
		    .pad_aon_gpioa_gpio_16_pad	    (),
		    .pad_aon_gpioa_gpio_17_pad      (),
		    .pad_aon_gpioa_gpio_18_pad	    (),
		    .pad_aon_gpioa_gpio_19_pad	    (),
		    .pad_aon_gpioa_gpio_20_pad	    (),
		    .pad_aon_gpioa_gpio_21_pad	    (),
		    .pad_aon_gpioa_gpio_22_pad	    (),
		    .pad_aon_gpioa_gpio_23_pad	    (),
		    .pad_aon_gpioa_gpio_24_pad      (),
		    .pad_aon_gpioa_gpio_25_pad      (),
		    .pad_aon_gpioa_gpio_26_pad      (),
		    .pad_aon_gpioa_gpio_27_pad      (),
		    .pad_aon_gpioa_gpio_28_pad      (),
		    .pad_aon_gpioa_gpio_29_pad      (),
		    .pad_aon_gpioa_gpio_30_pad      (),
		    .pad_aon_gpioa_gpio_31_pad      ()

		    );
   // chimera_top_wrapper #(
   //			 .SelectedCfg(SelectedCfg)
   //			 ) dut (
   //				.soc_clk_i              ( soc_clk       ),
   //				.clu_clk_i              ( clu_clk       ),
   //				.rst_ni             ( rst_n     ),
   //				.test_mode_i        ( test_mode ),
   //				.boot_mode_i        ( boot_mode ),
   //				.rtc_i              ( rtc       ),
   //				.jtag_tck_i         ( jtag_tck    ),
   //				.jtag_trst_ni       ( jtag_trst_n ),
   //				.jtag_tms_i         ( jtag_tms    ),
   //				.jtag_tdi_i         ( jtag_tdi    ),
   //				.jtag_tdo_o         ( jtag_tdo    ),
   //				.jtag_tdo_oe_o      ( ),
   //				.uart_tx_o          ( uart_tx ),
   //				.uart_rx_i          ( uart_rx ),
   //				.uart_rts_no        ( ),
   //				.uart_dtr_no        ( ),
   //				.uart_cts_ni        ( 1'b0 ),
   //				.uart_dsr_ni        ( 1'b0 ),
   //				.uart_dcd_ni        ( 1'b0 ),
   //				.uart_rin_ni        ( 1'b0 ),
   //				.i2c_sda_o          ( i2c_sda_o  ),
   //				.i2c_sda_i          ( i2c_sda_i  ),
   //				.i2c_sda_en_o       ( i2c_sda_en ),
   //				.i2c_scl_o          ( i2c_scl_o  ),
   //				.i2c_scl_i          ( i2c_scl_i  ),
   //				.i2c_scl_en_o       ( i2c_scl_en ),
   //				.spih_sck_o         ( spih_sck_o  ),
   //				.spih_sck_en_o      ( spih_sck_en ),
   //				.spih_csb_o         ( spih_csb_o  ),
   //				.spih_csb_en_o      ( spih_csb_en ),
   //				.spih_sd_o          ( spih_sd_o   ),
   //				.spih_sd_en_o       ( spih_sd_en  ),
   //				.spih_sd_i          ( spih_sd_i   ),
   //				.gpio_i             ( '0 ),
   //				.gpio_o             ( ),
   //				.gpio_en_o          ( ),
   //				.slink_rcv_clk_i    ( slink_rcv_clk_i ),
   //				.slink_rcv_clk_o    ( slink_rcv_clk_o ),
   //				.slink_i            ( slink_i ),
   //				.slink_o            ( slink_o ),
   //				.vga_hsync_o        ( ),
   //				.vga_vsync_o        ( ),
   //				.vga_red_o          ( ),
   //				.vga_green_o        ( ),
   //				.vga_blue_o         ( )
   //				);

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
