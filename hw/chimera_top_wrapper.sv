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
    input  logic                                            soc_clk_i,
    input  logic                                            clu_clk_i,
    input  logic                                            rst_ni,
    input  logic                                            test_mode_i,
    input  logic [                  1:0]                    boot_mode_i,
    input  logic                                            rtc_i,
    // JTAG interface
    input  logic                                            jtag_tck_i,
    input  logic                                            jtag_trst_ni,
    input  logic                                            jtag_tms_i,
    input  logic                                            jtag_tdi_i,
    output logic                                            jtag_tdo_o,
    output logic                                            jtag_tdo_oe_o,
    // UART interface
    output logic                                            uart_tx_o,
    input  logic                                            uart_rx_i,
    // UART modem flow control
    output logic                                            uart_rts_no,
    output logic                                            uart_dtr_no,
    input  logic                                            uart_cts_ni,
    input  logic                                            uart_dsr_ni,
    input  logic                                            uart_dcd_ni,
    input  logic                                            uart_rin_ni,
    // I2C interface
    output logic                                            i2c_sda_o,
    input  logic                                            i2c_sda_i,
    output logic                                            i2c_sda_en_o,
    output logic                                            i2c_scl_o,
    input  logic                                            i2c_scl_i,
    output logic                                            i2c_scl_en_o,
    // SPI host interface
    output logic                                            spih_sck_o,
    output logic                                            spih_sck_en_o,
    output logic [        SpihNumCs-1:0]                    spih_csb_o,
    output logic [        SpihNumCs-1:0]                    spih_csb_en_o,
    output logic [                  3:0]                    spih_sd_o,
    output logic [                  3:0]                    spih_sd_en_o,
    input  logic [                  3:0]                    spih_sd_i,
    // GPIO interface
    input  logic [                 31:0]                    gpio_i,
    output logic [                 31:0]                    gpio_o,
    output logic [                 31:0]                    gpio_en_o,
    // Serial link interface
    input  logic [     SlinkNumChan-1:0]                    slink_rcv_clk_i,
    output logic [     SlinkNumChan-1:0]                    slink_rcv_clk_o,
    input  logic [     SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_i,
    output logic [     SlinkNumChan-1:0][SlinkNumLanes-1:0] slink_o,
    // VGA interface
    output logic                                            vga_hsync_o,
    output logic                                            vga_vsync_o,
    output logic [ Cfg.VgaRedWidth -1:0]                    vga_red_o,
    output logic [Cfg.VgaGreenWidth-1:0]                    vga_green_o,
    output logic [Cfg.VgaBlueWidth -1:0]                    vga_blue_o
);

  `include "axi/typedef.svh"
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
      .Cfg(Cfg),
      .ExtHartinfo('0),
      .axi_ext_llc_req_t(axi_mst_req_t),
      .axi_ext_llc_rsp_t(axi_mst_rsp_t),
      .axi_ext_mst_req_t(axi_mst_req_t),
      .axi_ext_mst_rsp_t(axi_mst_rsp_t),
      .axi_ext_wide_mst_req_t(axi_wide_mst_req_t),
      .axi_ext_wide_mst_rsp_t(axi_wide_mst_rsp_t),
      .axi_ext_slv_req_t(axi_slv_req_t),
      .axi_ext_slv_rsp_t(axi_slv_rsp_t),
      .reg_ext_req_t(reg_req_t),
      .reg_ext_rsp_t(reg_rsp_t)
  ) i_cheshire (
      .clk_i(soc_clk_i),
      .rst_ni,
      .test_mode_i,
      .boot_mode_i,
      .rtc_i,
      // External AXI LLC (DRAM) port
      .axi_llc_mst_req_o(),
      .axi_llc_mst_rsp_i('0),
      // External AXI crossbar ports
      .axi_ext_mst_req_i(axi_mst_req),
      .axi_ext_mst_rsp_o(axi_mst_rsp),
      .axi_ext_wide_mst_req_i(axi_wide_mst_req),
      .axi_ext_wide_mst_rsp_o(axi_wide_mst_rsp),
      .axi_ext_slv_req_o(axi_slv_req),
      .axi_ext_slv_rsp_i(axi_slv_rsp),
      // External reg demux slaves
      .reg_ext_slv_req_o(reg_slv_req),
      .reg_ext_slv_rsp_i(reg_slv_rsp),
      // Interrupts from and to external targets
      .intr_ext_i(intr_ext_in),
      .intr_ext_o(intr_ext_out),
      // Interrupt requests to external harts
      .xeip_ext_o(xeip_ext),
      .mtip_ext_o(mtip_ext),
      .msip_ext_o(msip_ext),
      // Debug interface to external harts
      .dbg_active_o(dbg_active),
      .dbg_ext_req_o(dbg_ext_req),
      .dbg_ext_unavail_i(dbg_ext_unavail),
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
      .slink_rcv_clk_i,
      .slink_rcv_clk_o,
      .slink_i,
      .slink_o,
      // VGA interface
      .vga_hsync_o,
      .vga_vsync_o,
      .vga_red_o,
      .vga_green_o,
      .vga_blue_o
  );

  // TOP-LEVEL REG

  chimera_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) i_reg_top (
      .clk_i(soc_clk_i),
      .rst_ni,
      .reg_req_i(reg_slv_req[TopLevelIdx]),
      .reg_rsp_o(reg_slv_rsp[TopLevelIdx]),
      .reg2hw(reg2hw),
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

  // Cluster clock gates

  logic [ExtClusters-1:0] cluster_clock_gate_en;
  logic [ExtClusters-1:0] clu_clk_gated;
  assign cluster_clock_gate_en = {
    reg2hw.cluster_5_clk_gate_en,
    reg2hw.cluster_4_clk_gate_en,
    reg2hw.cluster_3_clk_gate_en,
    reg2hw.cluster_2_clk_gate_en,
    reg2hw.cluster_1_clk_gate_en
  };

  genvar extClusterIdx;
  generate
    for (extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++) begin : gen_clk_gates
      tc_clk_gating i_cluster_clk_gate (
          .clk_i(clu_clk_i),
          .en_i(~cluster_clock_gate_en[extClusterIdx]),
          .test_en_i(1'b0),
          .clk_o(clu_clk_gated[extClusterIdx])
      );
    end
  endgenerate

  // Synch debug signals & interrupts
  // SCHEREMO: These signals are synchronize in the Snitch cluster!

  logic [iomsb(NumIrqCtxts*Cfg.NumExtIrqHarts):0] clu_xeip_ext;
  logic [            iomsb(Cfg.NumExtIrqHarts):0] clu_mtip_ext;
  logic [            iomsb(Cfg.NumExtIrqHarts):0] clu_msip_ext;
  logic [            iomsb(Cfg.NumExtDbgHarts):0] clu_dbg_ext_req;

  assign clu_xeip_ext = xeip_ext;
  assign clu_mtip_ext = mtip_ext;
  assign clu_msip_ext = msip_ext;
  assign clu_dbg_ext_req = dbg_ext_req;

  // Clusters

  localparam int WideDataWidth = $bits(axi_wide_mst_req[0].w.data);

  localparam int WideSlaveIdWidth = $bits(axi_wide_mst_req[0].aw.id);
  localparam int NarrowSlaveIdWidth = $bits(axi_slv_req[0].aw.id);

  typedef logic [Cfg.AddrWidth-1:0] axi_cluster_addr_t;
  typedef logic [Cfg.AxiUserWidth-1:0] axi_cluster_user_t;

  typedef logic [Cfg.AxiDataWidth-1:0] axi_cluster_data_narrow_t;
  typedef logic [Cfg.AxiDataWidth/8-1:0] axi_cluster_strb_narrow_t;
  typedef logic [NarrowSlaveIdWidth +2 -1:0] axi_cluster_slv_id_width_narrow_t;

  typedef logic [WideDataWidth-1:0] axi_cluster_data_wide_t;
  typedef logic [WideDataWidth/8-1:0] axi_cluster_strb_wide_t;
  typedef logic [WideSlaveIdWidth +2 -1:0] axi_cluster_slv_id_width_wide_t;

  `AXI_TYPEDEF_ALL(axi_cluster_out_wide, axi_cluster_addr_t, axi_cluster_slv_id_width_wide_t,
                   axi_cluster_data_wide_t, axi_cluster_strb_wide_t, axi_cluster_user_t)
  `AXI_TYPEDEF_ALL(axi_cluster_out_narrow, axi_cluster_addr_t, axi_cluster_slv_id_width_narrow_t,
                   axi_cluster_data_narrow_t, axi_cluster_strb_narrow_t, axi_cluster_user_t)

  axi_slv_req_t                 [iomsb(ExtClusters):0] clu_axi_slv_req;
  axi_slv_rsp_t                 [iomsb(ExtClusters):0] clu_axi_slv_resp;
  axi_cluster_out_narrow_req_t  [iomsb(ExtClusters):0] clu_axi_mst_req;
  axi_cluster_out_narrow_resp_t [iomsb(ExtClusters):0] clu_axi_mst_resp;
  axi_cluster_out_wide_req_t    [iomsb(ExtClusters):0] clu_axi_wide_mst_req;
  axi_cluster_out_wide_resp_t   [iomsb(ExtClusters):0] clu_axi_wide_mst_resp;

  // Cluster Adapters
  logic                         [     ExtClusters-1:0] wide_mem_bypass_mode;
  assign wide_mem_bypass_mode = {
    reg2hw.wide_mem_cluster_5_bypass.q,
    reg2hw.wide_mem_cluster_4_bypass.q,
    reg2hw.wide_mem_cluster_3_bypass.q,
    reg2hw.wide_mem_cluster_2_bypass.q,
    reg2hw.wide_mem_cluster_1_bypass.q
  };

  generate
    for (
        extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++
    ) begin : gen_clusters_adapters

      chimera_cluster_adapter #(
          .WideSlaveIdWidth(WideSlaveIdWidth),

          .WidePassThroughRegionStart(Cfg.MemIslRegionStart),
          .WidePassThroughRegionEnd  (Cfg.MemIslRegionEnd),

          .narrow_in_req_t(axi_slv_req_t),
          .narrow_in_resp_t(axi_slv_rsp_t),
          .wide_in_req_t(axi_wide_slv_req_t),
          .wide_in_resp_t(axi_wide_slv_rsp_t),
          .narrow_out_req_t(axi_mst_req_t),
          .narrow_out_resp_t(axi_mst_rsp_t),
          .wide_out_req_t(axi_wide_mst_req_t),
          .wide_out_resp_t(axi_wide_mst_rsp_t),

          .clu_narrow_out_req_t(axi_cluster_out_narrow_req_t),
          .clu_narrow_out_resp_t(axi_cluster_out_narrow_resp_t),
          .clu_wide_out_req_t(axi_cluster_out_wide_req_t),
          .clu_wide_out_resp_t(axi_cluster_out_wide_resp_t)
      ) i_cluster_axi_adapter (
          .soc_clk_i(soc_clk_i),
          .clu_clk_i(clu_clk_gated[extClusterIdx]),
          .rst_ni,

          .narrow_in_req_i(axi_slv_req[extClusterIdx]),
          .narrow_in_resp_o(axi_slv_rsp[extClusterIdx]),
          .narrow_out_req_o(axi_mst_req[2*extClusterIdx+:2]),
          .narrow_out_resp_i(axi_mst_rsp[2*extClusterIdx+:2]),
          .wide_out_req_o(axi_wide_mst_req[extClusterIdx]),
          .wide_out_resp_i(axi_wide_mst_rsp[extClusterIdx]),

          .clu_narrow_in_req_o(clu_axi_slv_req[extClusterIdx]),
          .clu_narrow_in_resp_i(clu_axi_slv_resp[extClusterIdx]),
          .clu_narrow_out_req_i(clu_axi_mst_req[extClusterIdx]),
          .clu_narrow_out_resp_o(clu_axi_mst_resp[extClusterIdx]),
          .clu_wide_out_req_i(clu_axi_wide_mst_req[extClusterIdx]),
          .clu_wide_out_resp_o(clu_axi_wide_mst_resp[extClusterIdx]),

          //.wide_mem_bypass_mode(reg2hw.wide_mem_cluster_bypass.q)
          .wide_mem_bypass_mode_i(wide_mem_bypass_mode[extClusterIdx])
      );

    end  // block: gen_cluster_adapters
  endgenerate

  // Clusters

  typedef struct packed {
    logic [2:0] ema;
    logic [1:0] emaw;
    logic [0:0] emas;
  } sram_cfg_t;

  typedef struct packed {
    sram_cfg_t icache_tag;
    sram_cfg_t icache_data;
    sram_cfg_t tcdm;
  } sram_cfgs_t;

  localparam int unsigned NumIntOutstandingLoads[9] = '{1, 1, 1, 1, 1, 1, 1, 1, 1};
  localparam int unsigned NumIntOutstandingMem[9] = '{4, 4, 4, 4, 4, 4, 4, 4, 4};

  generate
    for (extClusterIdx = 0; extClusterIdx < ExtClusters; extClusterIdx++) begin : gen_clusters
      snitch_cluster #(
          .PhysicalAddrWidth(Cfg.AddrWidth),
          .NarrowDataWidth(Cfg.AxiDataWidth),
          .WideDataWidth(WideDataWidth),
          .NarrowIdWidthIn(NarrowSlaveIdWidth),
          .WideIdWidthIn(WideSlaveIdWidth),
          .NarrowUserWidth(Cfg.AxiUserWidth),
          .WideUserWidth(Cfg.AxiUserWidth),

          .BootAddr(SnitchBootROMRegionStart),

          .NrHives(1),
          .NrCores(9),
          .TCDMDepth(1024),
          .ZeroMemorySize(64),
          .ClusterPeriphSize(64),
          .NrBanks(16),

          .DMANumAxInFlight(3),
          .DMAReqFifoDepth (3),

          .ICacheLineWidth('{256}),
          .ICacheLineCount('{16}),
          .ICacheSets('{2}),

          .VMSupport(0),
          .Xdma(9'b100000000),

          .NumIntOutstandingLoads(NumIntOutstandingLoads),
          .NumIntOutstandingMem(NumIntOutstandingMem),
          .RegisterOffloadReq(1),
          .RegisterOffloadRsp(1),
          .RegisterCoreReq(1),
          .RegisterCoreRsp(1),

          .narrow_in_req_t(axi_slv_req_t),
          .narrow_in_resp_t(axi_slv_rsp_t),
          .wide_in_req_t(axi_wide_slv_req_t),
          .wide_in_resp_t(axi_wide_slv_rsp_t),

          .narrow_out_req_t(axi_cluster_out_narrow_req_t),
          .narrow_out_resp_t(axi_cluster_out_narrow_resp_t),
          .wide_out_req_t(axi_cluster_out_wide_req_t),
          .wide_out_resp_t(axi_cluster_out_wide_resp_t),

          .sram_cfg_t (sram_cfg_t),
          .sram_cfgs_t(sram_cfgs_t),

          .RegisterExtWide  ('0),
          .RegisterExtNarrow('0)
      ) i_test_cluster (

          .clk_i(clu_clk_i),
          .clk_d2_bypass_i('0),
          .rst_ni,

          .debug_req_i(clu_dbg_ext_req[extClusterIdx*9+:9]),
          .meip_i(clu_xeip_ext[extClusterIdx*9+:9]),
          .mtip_i(clu_mtip_ext[extClusterIdx*9+:9]),
          .msip_i(clu_msip_ext[extClusterIdx*9+:9]),

          .hart_base_id_i(10'(extClusterIdx * 9 + 1)),
          .cluster_base_addr_i(Cfg.AxiExtRegionStart[extClusterIdx][Cfg.AddrWidth-1:0]),
          .sram_cfgs_i('0),

          .narrow_in_req_i(clu_axi_slv_req[extClusterIdx]),
          .narrow_in_resp_o(clu_axi_slv_resp[extClusterIdx]),
          .narrow_out_req_o(clu_axi_mst_req[extClusterIdx]),
          .narrow_out_resp_i(clu_axi_mst_resp[extClusterIdx]),
          .wide_in_req_i('0),
          .wide_in_resp_o(),
          .wide_out_req_o(clu_axi_wide_mst_req[extClusterIdx]),
          .wide_out_resp_i(clu_axi_wide_mst_resp[extClusterIdx])

      );

    end  // block: gen_clusters
  endgenerate

endmodule
