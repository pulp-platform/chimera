// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package chimera_reg_pkg;

  // Address widths within the block
  parameter int BlockAw = 6;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    logic [31:0] q;
  } chimera_reg2hw_snitch_boot_addr_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } chimera_reg2hw_snitch_intr_handler_addr_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } chimera_reg2hw_snitch_cluster_1_return_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } chimera_reg2hw_snitch_cluster_2_return_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } chimera_reg2hw_snitch_cluster_3_return_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } chimera_reg2hw_snitch_cluster_4_return_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } chimera_reg2hw_snitch_cluster_5_return_reg_t;

  typedef struct packed {
    logic        q;
  } chimera_reg2hw_cluster_1_clk_gate_en_reg_t;

  typedef struct packed {
    logic        q;
  } chimera_reg2hw_cluster_2_clk_gate_en_reg_t;

  typedef struct packed {
    logic        q;
  } chimera_reg2hw_cluster_3_clk_gate_en_reg_t;

  typedef struct packed {
    logic        q;
  } chimera_reg2hw_cluster_4_clk_gate_en_reg_t;

  typedef struct packed {
    logic        q;
  } chimera_reg2hw_cluster_5_clk_gate_en_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } chimera_hw2reg_snitch_cluster_1_return_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } chimera_hw2reg_snitch_cluster_2_return_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } chimera_hw2reg_snitch_cluster_3_return_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } chimera_hw2reg_snitch_cluster_4_return_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } chimera_hw2reg_snitch_cluster_5_return_reg_t;

  // Register -> HW type
  typedef struct packed {
    chimera_reg2hw_snitch_boot_addr_reg_t snitch_boot_addr; // [228:197]
    chimera_reg2hw_snitch_intr_handler_addr_reg_t snitch_intr_handler_addr; // [196:165]
    chimera_reg2hw_snitch_cluster_1_return_reg_t snitch_cluster_1_return; // [164:133]
    chimera_reg2hw_snitch_cluster_2_return_reg_t snitch_cluster_2_return; // [132:101]
    chimera_reg2hw_snitch_cluster_3_return_reg_t snitch_cluster_3_return; // [100:69]
    chimera_reg2hw_snitch_cluster_4_return_reg_t snitch_cluster_4_return; // [68:37]
    chimera_reg2hw_snitch_cluster_5_return_reg_t snitch_cluster_5_return; // [36:5]
    chimera_reg2hw_cluster_1_clk_gate_en_reg_t cluster_1_clk_gate_en; // [4:4]
    chimera_reg2hw_cluster_2_clk_gate_en_reg_t cluster_2_clk_gate_en; // [3:3]
    chimera_reg2hw_cluster_3_clk_gate_en_reg_t cluster_3_clk_gate_en; // [2:2]
    chimera_reg2hw_cluster_4_clk_gate_en_reg_t cluster_4_clk_gate_en; // [1:1]
    chimera_reg2hw_cluster_5_clk_gate_en_reg_t cluster_5_clk_gate_en; // [0:0]
  } chimera_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    chimera_hw2reg_snitch_cluster_1_return_reg_t snitch_cluster_1_return; // [164:132]
    chimera_hw2reg_snitch_cluster_2_return_reg_t snitch_cluster_2_return; // [131:99]
    chimera_hw2reg_snitch_cluster_3_return_reg_t snitch_cluster_3_return; // [98:66]
    chimera_hw2reg_snitch_cluster_4_return_reg_t snitch_cluster_4_return; // [65:33]
    chimera_hw2reg_snitch_cluster_5_return_reg_t snitch_cluster_5_return; // [32:0]
  } chimera_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] CHIMERA_SNITCH_BOOT_ADDR_OFFSET = 6'h 0;
  parameter logic [BlockAw-1:0] CHIMERA_SNITCH_INTR_HANDLER_ADDR_OFFSET = 6'h 4;
  parameter logic [BlockAw-1:0] CHIMERA_SNITCH_CLUSTER_1_RETURN_OFFSET = 6'h 8;
  parameter logic [BlockAw-1:0] CHIMERA_SNITCH_CLUSTER_2_RETURN_OFFSET = 6'h c;
  parameter logic [BlockAw-1:0] CHIMERA_SNITCH_CLUSTER_3_RETURN_OFFSET = 6'h 10;
  parameter logic [BlockAw-1:0] CHIMERA_SNITCH_CLUSTER_4_RETURN_OFFSET = 6'h 14;
  parameter logic [BlockAw-1:0] CHIMERA_SNITCH_CLUSTER_5_RETURN_OFFSET = 6'h 18;
  parameter logic [BlockAw-1:0] CHIMERA_CLUSTER_1_CLK_GATE_EN_OFFSET = 6'h 1c;
  parameter logic [BlockAw-1:0] CHIMERA_CLUSTER_2_CLK_GATE_EN_OFFSET = 6'h 20;
  parameter logic [BlockAw-1:0] CHIMERA_CLUSTER_3_CLK_GATE_EN_OFFSET = 6'h 24;
  parameter logic [BlockAw-1:0] CHIMERA_CLUSTER_4_CLK_GATE_EN_OFFSET = 6'h 28;
  parameter logic [BlockAw-1:0] CHIMERA_CLUSTER_5_CLK_GATE_EN_OFFSET = 6'h 2c;

  // Register index
  typedef enum int {
    CHIMERA_SNITCH_BOOT_ADDR,
    CHIMERA_SNITCH_INTR_HANDLER_ADDR,
    CHIMERA_SNITCH_CLUSTER_1_RETURN,
    CHIMERA_SNITCH_CLUSTER_2_RETURN,
    CHIMERA_SNITCH_CLUSTER_3_RETURN,
    CHIMERA_SNITCH_CLUSTER_4_RETURN,
    CHIMERA_SNITCH_CLUSTER_5_RETURN,
    CHIMERA_CLUSTER_1_CLK_GATE_EN,
    CHIMERA_CLUSTER_2_CLK_GATE_EN,
    CHIMERA_CLUSTER_3_CLK_GATE_EN,
    CHIMERA_CLUSTER_4_CLK_GATE_EN,
    CHIMERA_CLUSTER_5_CLK_GATE_EN
  } chimera_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] CHIMERA_PERMIT [12] = '{
    4'b 1111, // index[ 0] CHIMERA_SNITCH_BOOT_ADDR
    4'b 1111, // index[ 1] CHIMERA_SNITCH_INTR_HANDLER_ADDR
    4'b 1111, // index[ 2] CHIMERA_SNITCH_CLUSTER_1_RETURN
    4'b 1111, // index[ 3] CHIMERA_SNITCH_CLUSTER_2_RETURN
    4'b 1111, // index[ 4] CHIMERA_SNITCH_CLUSTER_3_RETURN
    4'b 1111, // index[ 5] CHIMERA_SNITCH_CLUSTER_4_RETURN
    4'b 1111, // index[ 6] CHIMERA_SNITCH_CLUSTER_5_RETURN
    4'b 0001, // index[ 7] CHIMERA_CLUSTER_1_CLK_GATE_EN
    4'b 0001, // index[ 8] CHIMERA_CLUSTER_2_CLK_GATE_EN
    4'b 0001, // index[ 9] CHIMERA_CLUSTER_3_CLK_GATE_EN
    4'b 0001, // index[10] CHIMERA_CLUSTER_4_CLK_GATE_EN
    4'b 0001  // index[11] CHIMERA_CLUSTER_5_CLK_GATE_EN
  };

endpackage

