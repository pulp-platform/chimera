// ----------------------------------------------------------------------
//
// File: chimera_top_wrapper.sv
//
// Created: 24.06.2024
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


module fll_clk_gen #(
         parameter int AddrWidth = 48,
         parameter DataWidth = 32
  ) (
     input logic                  hse_clk_i, // High Speed External Clk
     input logic                  lse_clk_i, //Low Speed External Clk
     input logic                  sel_clk_i, // Clk selct signal
     input logic                  rst_ni, // Prikmary rst signal from the PAD
     input logic                  scan_en_i, // Scan enable
     input logic                  test_mode_i,

     input logic [AddrWidth-1:0]  apb_fll_paddr_i,
     input logic [DataWidth-1:0]  apb_fll_pwdata_i,
     input logic                  apb_fll_pwrite_i,
     input logic                  apb_fll_psel_i,
     input logic                  apb_fll_penable_i,
     output logic [DataWidth-1:0] apb_fll_prdata_o,
     output logic                 apb_fll_pready_o,
     output logic                 apb_fll_pslverr_o,
        //APB_BUS.Slave apb_fll_bus, // APB Slave Interface: To be connected with the SoC

     output logic                 soc_clk_o, // SoC Clk signal
     output logic                 clu_clk_o // Cluster Clk signal
     );

   logic        clk_fl_soc;
   logic        clk_fll_clu;

   logic                 soc_fll_master_req;
   logic                 soc_fll_master_wrn;
   logic [1:0]           soc_fll_master_addr;
   logic [DataWidth-1:0] soc_fll_master_wdata;
   logic                 soc_fll_master_ack;
   logic [DataWidth-1:0] soc_fll_master_rdata;
   logic                 soc_fll_master_lock;

   logic                 clu_fll_master_req;
   logic                 clu_fll_master_wrn;
   logic [1:0]           clu_fll_master_addr;
   logic [DataWidth-1:0] clu_fll_master_wdata;
   logic                 clu_fll_master_ack;
   logic [DataWidth-1:0] clu_fll_master_rdata;
   logic                 clu_fll_master_lock;



   // APB to FLL Interface
   apb_fll_if #(.APB_ADDR_WIDTH(AddrWidth)) apb_fll_if_i (
    .HCLK          ( soc_clk_o                    ),
    .HRESETn       ( rst_ni                       ),

    .PADDR         ( apb_fll_paddr_i            ),
    .PWDATA        ( apb_fll_pwdata_i           ),
    .PWRITE        ( apb_fll_pwrite_i           ),
    .PSEL          ( apb_fll_psel_i             ),
    .PENABLE       ( apb_fll_penable_i          ),
    .PRDATA        ( apb_fll_prdata_o           ),
    .PREADY        ( apb_fll_pready_o           ),
    .PSLVERR       ( apb_fll_pslverr_o          ),

    .fll1_req_o    ( soc_fll_master_req           ),
    .fll1_wrn_o    ( soc_fll_master_wrn           ),
    .fll1_add_o    ( soc_fll_master_addr          ),
    .fll1_data_o   ( soc_fll_master_wdata         ),
    .fll1_ack_i    ( soc_fll_master_ack           ),
    .fll1_r_data_i ( soc_fll_master_rdata         ),
    .fll1_lock_i   ( soc_fll_master_lock          ),

    .fll2_req_o    ( clu_fll_master_req           ),
    .fll2_wrn_o    ( clu_fll_master_wrn           ),
    .fll2_add_o    ( clu_fll_master_addr          ),
    .fll2_data_o   ( clu_fll_master_wdata         ),
    .fll2_ack_i    ( clu_fll_master_ack           ),
    .fll2_r_data_i ( clu_fll_master_rdata         ),
    .fll2_lock_i   ( clu_fll_master_lock          ),

    .fll3_req_o    ( ),
    .fll3_wrn_o    ( ),
    .fll3_add_o    ( ),
    .fll3_data_o   ( ),
    .fll3_ack_i    ('0),
    .fll3_r_data_i ('0),
    .fll3_lock_i   ('0),

    .bbgen_req_o   (),
    .bbgen_wrn_o   (),
    .bbgen_sel_o   (),
    .bbgen_data_o  (),
    .bbgen_ack_i   ('0),
    .bbgen_r_data_i('0),
    .bbgen_lock_i  ('0)
);

   // FLL for the Chimera SoC
   gf22_FLL i_gf22_fll_soc
     (
      .FLLCLK ( clk_fll_soc              ),
      .FLLOE  ( 1'b1                     ),
      .REFCLK ( lse_clk_i                ),
      .LOCK   ( soc_fll_master_lock      ),
      .CFGREQ ( soc_fll_master_req       ),
      .CFGACK ( soc_fll_master_ack       ),
      .CFGAD  ( soc_fll_master_addr      ),
      .CFGD   ( soc_fll_master_wdata     ),
      .CFGQ   ( soc_fll_master_rdata     ),
      .CFGWEB ( soc_fll_master_wrn       ),
      .RSTB   ( rst_ni                   ),
      .PWD    ( 1'b0                     ),
      .RET    ( 1'b0                     ),
      .TM     ( test_mode_i              ),
      .TE     ( scan_en_i                ),
      .TD     ( 1'b0                     ), //TO FIX DFT
      .TQ     (                          ), //TO FIX DFT
      .JTD    ( 1'b0                     ), //TO FIX DFT
      .JTQ    (                          )  //TO FIX DF
      );

   // FLL for the internal Clusters
   gf22_FLL i_gf22_fll_clusters
     (
      .FLLCLK ( clk_fll_clu              ),
      .FLLOE  ( 1'b1                     ),
      .REFCLK ( lse_clk_i                ),
      .LOCK   ( clu_fll_master_lock      ),
      .CFGREQ ( clu_fll_master_req       ),
      .CFGACK ( clu_fll_master_ack       ),
      .CFGAD  ( clu_fll_master_addr      ),
      .CFGD   ( clu_fll_master_wdata     ),
      .CFGQ   ( clu_fll_master_rdata     ),
      .CFGWEB ( clu_fll_master_wrn       ),
      .RSTB   ( rst_ni                   ),
      .PWD    ( 1'b0                     ),
      .RET    ( 1'b0                     ),
      .TM     ( test_mode_i              ),
      .TE     ( scan_en_i                ),
      .TD     ( 1'b0                     ), //TO FIX DFT
      .TQ     (                          ), //TO FIX DFT
      .JTD    ( 1'b0                     ), //TO FIX DFT
      .JTQ    (                          )  //TO FIX DF
      );

   // Bypass FLL if sel_clk_i = 1
   always_comb begin
      if (sel_clk_i == 1'b1) begin
   soc_clk_o = hse_clk_i;
   clu_clk_o = hse_clk_i;
      end else begin
   soc_clk_o = clk_fll_soc;
   clu_clk_o = clk_fll_clu;
      end
   end


endmodule // fll_clk_gen
