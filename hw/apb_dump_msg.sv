// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Lorenzo Leone <lleone@iis.ee.ethz.ch>
//
// This module is introduced to improve the system debuggability.
// When the target synthesis is used, teh module behaves as a bypass
// for teh APB messages.
// During simulation instead, the APB messages directed to teh
// DUMP address 0x30004ffc are printed in a UART fashion on teh console.

module apb_dump_msg
  import chimera_pkg::*;
#(
  parameter logic        [31:0] DumpAddr  = 32'h30004ffc,
  parameter int unsigned        DataWidth = 32
) (
  input  logic      clk_i,
  input  logic      rst_ni,
  // From Top
  output apb_resp_t apb_rsp_o,
  input  apb_req_t  apb_req_i,
  // To Top
  input  apb_resp_t apb_rsp_i,
  output apb_req_t  apb_req_o
);

`ifdef SYNTHESIS
  assign apb_req_o = apb_req_i;
  assign apb_rsp_o = apb_rsp_i;
`else

  logic dump;

  assign dump = apb_req_i.psel && apb_req_i.penable && apb_req_i.pwrite&&
                (apb_req_i.paddr == DumpAddr);

  always_comb begin : gen_dump
    apb_req_o = apb_req_i;
    apb_rsp_o = apb_rsp_i;
    // Mask teh APB request if targetting the dump address
    if (dump) begin : gen_mask_req
      apb_req_o.psel    = 1'b0;
      apb_req_o.penable = 1'b0;
      apb_rsp_o.pready  = 1'b1;
    end
  end


  // pragma translate_off
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // no state
    end else if (dump) begin
      for (int unsigned i = 0; i < DataWidth / 8; i++) begin
        // Use strobe if present; otherwise always print all bytes.
        if (apb_req_i.pstrb[i]) begin
          logic [7:0] ch;
          ch = apb_req_i.pwdata[i*8+:8];
          if (ch == 8'h0A) begin : gen_print_newline
            $display("");
          end else begin : gen_print_char
            $write("%c", ch);
          end
        end
      end
    end
  end
  // pragma translate_on

`endif
endmodule
