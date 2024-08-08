// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>

`define map_gpio(_group,_indx) \
assign port_signals_soc2pad_o.aon_gpio``_group.gpio``_group``_indx.gpio``_o = gpio_i``[``_indx``]; \
assign port_signals_soc2pad_o.aon_gpio``_group.gpio``_group``_indx.gpio``_en_o = gpio_en_i``[``_indx``]; \
assign gpio_o``[``_indx``] = port_signals_pad2soc_i.aon_gpio``_group.gpio``_group``_indx.gpio``_i;




module pad_soc_intf
  import pkg_chimera_padframe::*;
  import cheshire_pkg::*;
  //import chimera_pkg::*;
  (
   //output logic          soc_clk_o,
   output logic          rst_no,
   output logic [1:0]        boot_mode_o,

   // Static signals from/to the padframe
   input           static_connection_signals_pad2soc_t static_connections_pad2soc_i,
   output          static_connection_signals_soc2pad_t static_connections_soc2pad_o,

   // Muxed signals from/to the padframe
   input           port_signals_pad2soc_t port_signals_pad2soc_i,
   output          port_signals_soc2pad_t port_signals_soc2pad_o,

   // Chimera IO signals

   // JTAG interface
   output logic          jtag_tck_o,
   output logic          jtag_trst_no,
   output logic          jtag_tms_o,
   output logic          jtag_tdi_o,
   input logic           jtag_tdo_i,
   // input logic          jtag_tdo_oe_i,
   // UART interface
   input logic           uart_tx_i,
   output logic          uart_rx_o,
   // I2C interface
   input logic           i2c_sda_i,
   output logic          i2c_sda_o,
   input logic           i2c_sda_en_i,
   output logic          i2c_scl_o,
   input logic           i2c_scl_i,
   input logic           i2c_scl_en_i,
   // SPI host interface
   input logic           spih_sck_i,
   input logic           spih_sck_en_i,
   input logic [SpihNumCs-1:0] spih_csb_i,
   input logic [SpihNumCs-1:0] spih_csb_en_i,
   input logic [ 3:0]        spih_sd_i,
   input logic [ 3:0]        spih_sd_en_i,
   output logic [ 3:0]         spih_sd_o,
   // GPIO interface
   input logic [31:0]        gpio_i,
   output logic [31:0]         gpio_o,
   input logic [31:0]        gpio_en_i
   );

   // Connect static pads to SoC signals
   assign rst_no       = static_connections_pad2soc_i.aon_static.st_rstn;
   //assign soc_clk_o    = static_connections_pad2soc_i.aon_static.st_hse_clk;  // TODO: which clk should be connected here???
   assign boot_mode_o  = {static_connections_pad2soc_i.aon_static.st_bootsel_1, static_connections_pad2soc_i.aon_static.st_bootsel_0};
   assign jtag_tck_o   = static_connections_pad2soc_i.aon_static.st_jtag_tck;
   assign jtag_trst_no = static_connections_pad2soc_i.aon_static.st_jtag_trstn;
   assign jtag_tms_o   = static_connections_pad2soc_i.aon_static.st_jtag_tms;
   assign jtag_tdi_o   = static_connections_pad2soc_i.aon_static.st_jtag_tdi;

   assign static_connections_soc2pad_o.aon_static.st_jtag_tdo    = jtag_tdo_i;
   //assign static_connections_soc2pad_o.aon_static.st_jtag_tdo_oe = jtag_tdo_oe_i;

   // Connect dynamic pads to the SoC signals
   // UART
   assign uart_rx_o = port_signals_pad2soc_i.aon_gpioa.uart0.rx_i;
   assign port_signals_soc2pad_o.aon_gpioa.uart0.tx_o = uart_tx_i;

   // I2C0
   assign i2c_sda_o = port_signals_pad2soc_i.aon_gpioa.i2c0.sda_i;
   assign i2c_scl_o = port_signals_pad2soc_i.aon_gpioa.i2c0.scl_i;

   assign port_signals_soc2pad_o.aon_gpioa.i2c0.scl_en_o = i2c_scl_en_i;
   assign port_signals_soc2pad_o.aon_gpioa.i2c0.scl_o = i2c_scl_i;
   assign port_signals_soc2pad_o.aon_gpioa.i2c0.sda_en_o = i2c_sda_en_i;
   assign port_signals_soc2pad_o.aon_gpioa.i2c0.sda_o = i2c_sda_i;

   //QSPI0
   assign spih_sd_o[0] = port_signals_pad2soc_i.aon_gpioa.qspi0.sd0_i;
   assign spih_sd_o[1] = port_signals_pad2soc_i.aon_gpioa.qspi0.sd1_i;
   assign spih_sd_o[2] = port_signals_pad2soc_i.aon_gpioa.qspi0.sd2_i;
   assign spih_sd_o[3] = port_signals_pad2soc_i.aon_gpioa.qspi0.sd3_i;

   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sd0_o = spih_sd_i[0];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sd1_o = spih_sd_i[1];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sd2_o = spih_sd_i[2];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sd3_o = spih_sd_i[3];

   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sd0_en_o = spih_sd_en_i[0];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sd1_en_o = spih_sd_en_i[1];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sd2_en_o = spih_sd_en_i[2];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sd3_en_o = spih_sd_en_i[3];

   assign port_signals_soc2pad_o.aon_gpioa.qspi0.csb0_en_o = spih_csb_en_i[0];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.csb1_en_o = spih_csb_en_i[1];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.csb2_en_o = spih_csb_en_i[2];

   assign port_signals_soc2pad_o.aon_gpioa.qspi0.csb0_o = spih_csb_i[0];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.csb1_o = spih_csb_i[1];
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.csb2_o = spih_csb_i[2];

   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sck_o = spih_sck_i;
   assign port_signals_soc2pad_o.aon_gpioa.qspi0.sck_en_o = spih_sck_en_i;

   // GPIO
   `map_gpio(a,0);
   `map_gpio(a,1);
   `map_gpio(a,2);
   `map_gpio(a,3);
   `map_gpio(a,4);
   `map_gpio(a,5);
   `map_gpio(a,6);
   `map_gpio(a,7);
   `map_gpio(a,8);
   `map_gpio(a,9);
   `map_gpio(a,10);
   `map_gpio(a,11);
   `map_gpio(a,12);
   `map_gpio(a,13);
   `map_gpio(a,14);
   `map_gpio(a,15);
   `map_gpio(a,16);
   `map_gpio(a,17);
   `map_gpio(a,18);
   `map_gpio(a,19);
   `map_gpio(a,20);
   `map_gpio(a,21);
   `map_gpio(a,22);
   `map_gpio(a,23);
   `map_gpio(a,24);
   `map_gpio(a,25);
   `map_gpio(a,26);
   `map_gpio(a,27);
   `map_gpio(a,28);
   `map_gpio(a,29);
   `map_gpio(a,30);
   `map_gpio(a,31);

endmodule // pad_soc_intf
