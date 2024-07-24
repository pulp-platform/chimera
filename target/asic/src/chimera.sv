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
   inout wire logic pad_aon_static_bootsel_pad,
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

   static_connection_signals_pad2soc_t static_connection_signals_pad2soc;
   static_connection_signals_soc2pad_t static_connection_signals_soc2pad;
   
   port_signals_pad2soc_t              port_signals_pad2soc;
   port_signals_soc2pad_t              port_signals_soc2pad;

   // Cheshire config
   localparam cheshire_cfg_t Cfg = ChimeraCfg[0];
   `CHESHIRE_TYPEDEF_ALL(, Cfg)


   chimera_padframe #(
		      .AW(Cfg.AddrWidth),
		      .(32)
		      .req_t (),
		      .resp_t ()
		      ) i_chimera
      (
       .clk_i,
       .rst_ni,
       .override_signals,
       .static_connection_signals_pad2soc,
       .static_connection_signals_soc2pad,
       .port_signals_pad2soc,
       .port_signals_soc2pad,
      
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
       .pad_aon_static_bootsel_pad,
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
       .pad_aon_gpioa_gpio_10_pad
       .pad_aon_gpioa_gpio_11_pad
       .pad_aon_gpioa_gpio_12_pad
       .pad_aon_gpioa_gpio_13_pad
       .pad_aon_gpioa_gpio_14_pad
       .pad_aon_gpioa_gpio_15_pad
       .pad_aon_gpioa_gpio_16_pad
       .pad_aon_gpioa_gpio_17_pad
       .pad_aon_gpioa_gpio_18_pad
       .pad_aon_gpioa_gpio_19_pad
       .pad_aon_gpioa_gpio_20_pad
       .pad_aon_gpioa_gpio_21_pad
       .pad_aon_gpioa_gpio_22_pad
       .pad_aon_gpioa_gpio_23_pad
       .pad_aon_gpioa_gpio_24_pad
       .pad_aon_gpioa_gpio_25_pad
       .pad_aon_gpioa_gpio_26_pad
       .pad_aon_gpioa_gpio_27_pad
       .pad_aon_gpioa_gpio_28_pad
       .pad_aon_gpioa_gpio_29_pad
       .pad_aon_gpioa_gpio_30_pad
       .pad_aon_gpioa_gpio_31_pad

      );
   

      endmodule // chimera
