// ----------------------------------------------------------------------
//
// File: pad_soc_intf.sv
//
// Created: 24.07.2024
//
// Copyright (C) 2024, ETH Zurich and University of Bologna.
//
// Author: Lorenzo Leone, ETH Zurich
//
// SPDX-License-Identifier: SHL-0.51
//
// Copyright and related rights are licensed under the Solderpad Hardware License,
// Version 0.51 (the "License"); you may not use this file except in compliance with
// the License. You may obtain a copy of the License at http://solderpad.org/licenses/SHL-0.51.
// Unless required by applicable law or agreed to in writing, software, hardware and materials
// distributed under this License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and limitations under the License.
//
// ----------------------------------------------------------------------

module chimera
  import pkg_chimera_padframe::*;
   import cheshire_pkg::*;
   import chimera_pkg::*;
   import chimera_reg_pkg::*;
   #(
     parameter int unsigned SelectedCfg = 0
     )
   (
   inout wire logic pad_aon_static_lse_clk_pad,
   inout wire logic pad_aon_static_hse_clk_pad,
   inout wire logic pad_aon_static_byp_sel_clk_pad,
   inout wire logic pad_aon_static_rstn_pad,
   inout wire logic pad_aon_static_jtag_tck_pad,
   inout wire logic pad_aon_static_jtag_trstn_pad,
   inout wire logic pad_aon_static_jtag_tms_pad,
   inout wire logic pad_aon_static_jtag_tdi_pad,
   inout wire logic pad_aon_static_jtag_tdo_pad,
   inout wire logic pad_aon_static_bootsel_0_pad,
   inout wire logic pad_aon_static_bootsel_1_pad,
   inout wire logic pad_aon_gpioa_gpio_0_pad,
   inout wire logic pad_aon_gpioa_gpio_1_pad,
   inout wire logic pad_aon_gpioa_gpio_2_pad,
   inout wire logic pad_aon_gpioa_gpio_3_pad,
   inout wire logic pad_aon_gpioa_gpio_4_pad,
   inout wire logic pad_aon_gpioa_gpio_5_pad,
   inout wire logic pad_aon_gpioa_gpio_6_pad,
   inout wire logic pad_aon_gpioa_gpio_7_pad,
   inout wire logic pad_aon_gpioa_gpio_8_pad,
   inout wire logic pad_aon_gpioa_gpio_9_pad,
   inout wire logic pad_aon_gpioa_gpio_10_pad,
   inout wire logic pad_aon_gpioa_gpio_11_pad,
   inout wire logic pad_aon_gpioa_gpio_12_pad,
   inout wire logic pad_aon_gpioa_gpio_13_pad,
   inout wire logic pad_aon_gpioa_gpio_14_pad,
   inout wire logic pad_aon_gpioa_gpio_15_pad,
   inout wire logic pad_aon_gpioa_gpio_16_pad,
   inout wire logic pad_aon_gpioa_gpio_17_pad,
   inout wire logic pad_aon_gpioa_gpio_18_pad,
   inout wire logic pad_aon_gpioa_gpio_19_pad,
   inout wire logic pad_aon_gpioa_gpio_20_pad,
   inout wire logic pad_aon_gpioa_gpio_21_pad,
   inout wire logic pad_aon_gpioa_gpio_22_pad,
   inout wire logic pad_aon_gpioa_gpio_23_pad,
   inout wire logic pad_aon_gpioa_gpio_24_pad,
   inout wire logic pad_aon_gpioa_gpio_25_pad,
   inout wire logic pad_aon_gpioa_gpio_26_pad,
   inout wire logic pad_aon_gpioa_gpio_27_pad,
   inout wire logic pad_aon_gpioa_gpio_28_pad,
   inout wire logic pad_aon_gpioa_gpio_29_pad,
   inout wire logic pad_aon_gpioa_gpio_30_pad,
   inout wire logic pad_aon_gpioa_gpio_31_pad
  );

`include "cheshire/typedef.svh"

   // Cheshire config
   localparam cheshire_cfg_t Cfg = ChimeraCfg[SelectedCfg];
   `CHESHIRE_TYPEDEF_ALL(, Cfg)

   localparam int unsigned AddrWidth = Cfg.AddrWidth;
   localparam int unsigned DataWidth = 32;

   static_connection_signals_pad2soc_t static_connection_signals_pad2soc;
   static_connection_signals_soc2pad_t static_connection_signals_soc2pad;

   port_signals_pad2soc_t              port_signals_pad2soc;
   port_signals_soc2pad_t              port_signals_soc2pad;

   // Signals from/to pad and Chimera inetrface
   logic       soc_clk;
   logic       clu_clk;
   logic       rst_n;
   logic [1:0] boot_mode;
   // JTAG
   logic                 jtag_tck_pad2soc;
   logic                 jtag_trst_n_pad2soc;
   logic                 jtag_tms_pad2soc;
   logic                 jtag_tdi_pad2soc;
   logic                 jtag_tdo_soc2pad;
   logic                 jtag_tdo_oe_soc2pad;

   // UART
   logic                 uart_rx_pad2soc;
   logic                 uart_tx_soc2pad;

   //I2C
   logic                 i2c_sda_pad2soc;
   logic                 i2c_sda_soc2pad;
   logic                 i2c_sda_en_soc2pad;
   logic                 i2c_scl_soc2pad;
   logic                 i2c_scl_pad2soc;
   logic                 i2c_scl_en_soc2pad;

   //SPI
   logic                 spih_sck_soc2pad;
   logic                 spih_sck_en_soc2pad;
   logic [SpihNumCs-1:0] spih_csb_soc2pad;
   logic [SpihNumCs-1:0] spih_csb_en_soc2pad;
   logic [3:0]		 spih_sd_soc2pad;
   logic [3:0]		 spih_sd_en_soc2pad;
   logic [3:0]		 spih_sd_pad2soc;

   //GPIO
   logic [31:0]		 gpio_pad2soc;
   logic [31:0]		 gpio_soc2pad;
   logic [31:0]		 gpio_en_soc2pad;


   reg_req_t config_reg_req;
   reg_rsp_t config_reg_rsp;

   apb_req_t  config_apb_fll_req;
   apb_resp_t config_apb_fll_rsp;

   apb_req_t  config_apb_req;
   apb_resp_t config_apb_rsp;

   REG_BUS #(
             .ADDR_WIDTH(AddrWidth),
             .DATA_WIDTH(DataWidth)
             ) reg_bus_if
     (
      .clk_i (soc_clk)
      );

   //APB_BUS apb_fll_bus();

   // CHIMERA PADFRAME
   chimera_padframe #(
          .AW (AddrWidth),
          .DW (DataWidth),
          .req_t (reg_req_t),
          .resp_t (reg_rsp_t)
          ) i_chimera_padframe
      (
       .clk_i ('0),
       .rst_ni ('0),
       .static_connection_signals_pad2soc (static_connection_signals_pad2soc),
       .static_connection_signals_soc2pad (static_connection_signals_soc2pad),
       .port_signals_pad2soc              (port_signals_pad2soc),
       .port_signals_soc2pad              (port_signals_soc2pad),

       // Config interface
       .config_req_i (config_reg_req),
       .config_rsp_o (config_reg_rsp),

       // pads
       .pad_aon_static_lse_clk_pad,
       .pad_aon_static_hse_clk_pad,
       .pad_aon_static_byp_sel_clk_pad,
       .pad_aon_static_rstn_pad,
       .pad_aon_static_jtag_tck_pad,
       .pad_aon_static_jtag_trstn_pad,
       .pad_aon_static_jtag_tms_pad,
       .pad_aon_static_jtag_tdi_pad,
       .pad_aon_static_jtag_tdo_pad,
       .pad_aon_static_bootsel_0_pad,
       .pad_aon_static_bootsel_1_pad,
       .pad_aon_gpioa_gpio_0_pad,
       .pad_aon_gpioa_gpio_1_pad,
       .pad_aon_gpioa_gpio_2_pad,
       .pad_aon_gpioa_gpio_3_pad,
       .pad_aon_gpioa_gpio_4_pad,
       .pad_aon_gpioa_gpio_5_pad,
       .pad_aon_gpioa_gpio_6_pad,
       .pad_aon_gpioa_gpio_7_pad,
       .pad_aon_gpioa_gpio_8_pad,
       .pad_aon_gpioa_gpio_9_pad,
       .pad_aon_gpioa_gpio_10_pad,
       .pad_aon_gpioa_gpio_11_pad,
       .pad_aon_gpioa_gpio_12_pad,
       .pad_aon_gpioa_gpio_13_pad,
       .pad_aon_gpioa_gpio_14_pad,
       .pad_aon_gpioa_gpio_15_pad,
       .pad_aon_gpioa_gpio_16_pad,
       .pad_aon_gpioa_gpio_17_pad,
       .pad_aon_gpioa_gpio_18_pad,
       .pad_aon_gpioa_gpio_19_pad,
       .pad_aon_gpioa_gpio_20_pad,
       .pad_aon_gpioa_gpio_21_pad,
       .pad_aon_gpioa_gpio_22_pad,
       .pad_aon_gpioa_gpio_23_pad,
       .pad_aon_gpioa_gpio_24_pad,
       .pad_aon_gpioa_gpio_25_pad,
       .pad_aon_gpioa_gpio_26_pad,
       .pad_aon_gpioa_gpio_27_pad,
       .pad_aon_gpioa_gpio_28_pad,
       .pad_aon_gpioa_gpio_29_pad,
       .pad_aon_gpioa_gpio_30_pad,
       .pad_aon_gpioa_gpio_31_pad
      );

   // |---------------------------------------------------------------------|
   // |                 Interface SoC <--> Padframe                         |
   // |---------------------------------------------------------------------|

   pad_soc_intf i_pad_soc_intf
     (
      //.soc_clk_o (soc_clk),
      .rst_no (rst_n),
      .boot_mode_o (boot_mode),

      .static_connections_pad2soc_i (static_connection_signals_pad2soc) ,
      .static_connections_soc2pad_o   (static_connection_signals_soc2pad),
      .port_signals_pad2soc_i        (port_signals_pad2soc),
      .port_signals_soc2pad_o        (port_signals_soc2pad),

      .jtag_tck_o                   (jtag_tck_pad2soc),
      .jtag_trst_no                 (jtag_trst_n_pad2soc),
      .jtag_tms_o                   (jtag_tms_pad2soc),
      .jtag_tdi_o                   (jtag_tdi_pad2soc),
      .jtag_tdo_i                   (jtag_tdo_soc2pad),
      //.jtag_tdo_oe_i                (jtag_tdo_oe_soc2pad),

      .uart_tx_i                    (uart_rx_pad2soc),
      .uart_rx_o                    (uart_tx_soc2pad),

      .i2c_sda_i                    (i2c_sda_soc2pad),
      .i2c_sda_o                    (i2c_sda_pad2soc),
      .i2c_sda_en_i                 (i2c_sda_en_soc2pad),
      .i2c_scl_o                    (i2c_scl_pad2soc),
      .i2c_scl_i                    (i2c_scl_soc2pad),
      .i2c_scl_en_i                 (i2c_scl_en_soc2pad),

      .spih_sck_i                   (spih_sck_soc2pad),
      .spih_sck_en_i                (spih_sck_en_soc2pad),
      .spih_csb_i                   (spih_csb_soc2pad),
      .spih_csb_en_i                (spih_csb_en_soc2pad),
      .spih_sd_i                    (spih_sd_soc2pad),
      .spih_sd_en_i                 (spih_sd_en_soc2pad),
      .spih_sd_o                    (spih_sd_pad2soc),

      .gpio_i                       (gpio_soc2pad),
      .gpio_o                       (gpio_pad2soc),
      .gpio_en_i                    (gpio_en_soc2pad)

      );

   // |---------------------------------------------------------------------|
   // |                        Reg-APB interface                            |
   // |---------------------------------------------------------------------|

   // Convert APB to RegBus for padframe registers
   apb_to_reg i_apb_to_reg
     (
      .clk_i (soc_clk),
      .rst_ni (rst_n),
      .penable_i (config_apb_req.penable),
      .pwrite_i  (config_apb_req.pwrite),
      .paddr_i   (config_apb_req.paddr[AddrWidth-16-1:0]), // Truncate first 16 MSBs beacuse module accepts 32 AddrWidth only
      .psel_i    (config_apb_req.psel),
      .pwdata_i  (config_apb_req.pwdata),
      .prdata_o  (config_apb_rsp.prdata),
      .pready_o  (config_apb_rsp.pready),
      .pslverr_o (config_apb_rsp.pslverr),
      .reg_o     (reg_bus_if)
      );

   // Connect RegBus to Padframe
   assign config_reg_req.addr = reg_bus_if.addr;
   assign config_reg_req.write = reg_bus_if.write;
   assign config_reg_req.wdata = reg_bus_if.wdata;
   assign config_reg_req.wstrb = reg_bus_if.wstrb;
   assign config_reg_req.valid = reg_bus_if.valid;
   assign reg_bus_if.rdata = config_reg_rsp.rdata;
   assign reg_bus_if.error = config_reg_rsp.error;
   assign reg_bus_if.ready = config_reg_rsp.ready;

   // Connect APB to FLL
   fll_clk_gen  #(
                  .AddrWidth(AddrWidth),
                  .DataWidth(DataWidth)
                  ) i_fll_clk_gen
     (
      .hse_clk_i   (static_connection_signals_pad2soc.aon_static.st_hse_clk),
      .lse_clk_i   (static_connection_signals_pad2soc.aon_static.st_lse_clk),
      .sel_clk_i   (static_connection_signals_pad2soc.aon_static.st_byp_clk_sel),
      .rst_ni      (static_connection_signals_pad2soc.aon_static.st_rstn),
      .scan_en_i   ('0),
      .test_mode_i ('0),

      .apb_fll_paddr_i   (config_apb_fll_req.paddr),
      .apb_fll_pwdata_i  (config_apb_fll_req.pwdata),
      .apb_fll_pwrite_i  (config_apb_fll_req.pwrite),
      .apb_fll_psel_i    (config_apb_fll_req.psel),
      .apb_fll_penable_i (config_apb_fll_req.penable),
      .apb_fll_prdata_o  (config_apb_fll_rsp.prdata),
      .apb_fll_pready_o  (config_apb_fll_rsp.pready),
      .apb_fll_pslverr_o (config_apb_fll_rsp.pslverr),

      .soc_clk_o (soc_clk),
      .clu_clk_o (clu_clk)
      );


   // |---------------------------------------------------------------------|
   // |                          Chimera SoC                                |
   // |---------------------------------------------------------------------|

   chimera_top_wrapper #(
       .SelectedCfg(0)
       ) i_chimera_top_wrapper
     (
      .soc_clk_i    (soc_clk),
      .clu_clk_i    (clu_clk),
      .rst_ni       (rst_n),
      .test_mode_i  ('0),
      .boot_mode_i  (boot_mode),
      // TODO: CHECK THIS ISGNAL
      .rtc_i ('0),

      .jtag_tck_i            (jtag_tck_pad2soc),
      .jtag_trst_ni      (jtag_trst_n_pad2soc),
      .jtag_tms_i      (jtag_tms_pad2soc),
      .jtag_tdi_i      (jtag_tdi_pad2soc),
      .jtag_tdo_o      (jtag_tdo_soc2pad),
      .jtag_tdo_oe_o       (),
//      .jtag_tdo_oe_o       (jtag_tdo_oe_soc2pad),

      .uart_tx_o             (uart_rx_soc2pad),
      .uart_rx_i       (uart_tx_pad2soc),

      /* According to Alessandro Ottaviano */
      /* these signals can be undriven     */
      // .uart_rts_no,
      // .uart_dtr_no,
      // .uart_cts_ni,
      // .uart_dsr_ni,
      // .uart_dcd_ni,
      // .uart_rin_ni,

      .i2c_sda_o             (i2c_sda_soc2pad),
      .i2c_sda_i       (i2c_sda_pad2soc),
      .i2c_sda_en_o      (i2c_sda_en_soc2pad),
      .i2c_scl_o       (i2c_scl_soc2pad),
      .i2c_scl_i       (i2c_scl_pad2soc),
      .i2c_scl_en_o      (i2c_scl_en_soc2pad),

      .spih_sck_o      (spih_sck_soc2pad),
      .spih_sck_en_o       (spih_sck_en_soc2pad),
      .spih_csb_o      (spih_csb_soc2pad),
      .spih_csb_en_o       (spih_csb_en_soc2pad),
      .spih_sd_o       (spih_sd_soc2pad),
      .spih_sd_en_o      (spih_sd_en_soc2pad),
      .spih_sd_i       (spih_sd_pad2soc),

      .gpio_i        (gpio_pad2soc),
      .gpio_o        (gpio_soc2pad),
      .gpio_en_o       (gpio_en_soc2pad),

      .apb_fll_req_o             (config_apb_fll_req),
      .apb_fll_rsp_i             (config_apb_fll_rsp),

      .apb_req_o             (config_apb_req),
      .apb_rsp_i             (config_apb_rsp)

      // .slink_rcv_clk_i,
      // .slink_rcv_clk_o,
      // .slink_i,
      // .slink_o,

      // .vga_hsync_o,
      // .vga_vsync_o,
      // .vga_red_o,
      // .vga_green_o,
      // .vga_blue_o

      );

endmodule // chimera
